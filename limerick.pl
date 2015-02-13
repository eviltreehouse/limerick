#!/usr/bin/env perl
use strict;
use FindBin;
require File::Spec;
use Getopt::Long qw/GetOptionsFromArray/;

use lib "$FindBin::Bin/lib";
require Limerick;
use Limerick::Output;

#---------------------------------------------------------------#
# Commands:
# limerick setup
# limerick app 
# limerick build
#---------------------------------------------------------------#
my %commands = (
	'setup' => \&cmd_setup,
	'app-add'   => \&cmd_app_add,
	'app-new'   => \&cmd_app_new,
	'app-on' => \&cmd_app_activate,
	'app-off' => \&cmd_app_deactivate,
	'app-list' => \&cmd_app_list,
	'app-status' => \&cmd_app_status,
	'build' => \&cmd_build,
	'test'  => \&cmd_test
);

if (! $commands{ lc $ARGV[0] } || (lc $ARGV[0] =~ m/^-?-?help/)) {
	print "limerick version " . $Limerick::VERSION . "\n";
	cout "Supported commands are: " . join(", ", sort keys %commands) . "\n";
	exit 1;
} else {
	exit &{ $commands{ lc $ARGV[0] } }( @ARGV );
}

sub cmd_setup {
	my $skel_file = "$FindBin::Bin/skel/limerick-config.json-dist";
	my $dest_file = "$FindBin::Bin/limerick-config.json";

	if (! -f $skel_file) {
		cerr "Skeleton configuration does not exist!";
		return 1;
	} elsif (-f $dest_file) {
		cerr "limerick-config.json already exists! Move it out of the way first.";
		return 1;
	}

	`cp $skel_file $dest_file 2>/dev/null`;
	if ($? != 0) {
		cerr "Unable to write to $dest_file. Ensure you have permissions.";
		return 1;
	}

	cout "Base configuration file written successfully.";
	return 0;
}

sub cmd_app_status {
	my $app = $ARGV[1];

	if (my $L = _startupAndParse()) {
		my $appc = $L->config->for_app($app);
		if (! defined $appc->{'approot'}) {
			cerr "Unable to find '$app'";
			cnotify "Available apps: " . join(", ", keys %{ $L->all_apps });
			return 1; 
		} else {
			my $pidfile = File::Spec->catfile($appc->{'approot'}, 'bin', 'tmp', 'run.pid');
			if (! -r $pidfile) {
				print "Offline\n";
				return 0;
			} else {
				open(PIDF, "<", $pidfile);
				chomp(my $pid = <PIDF>);
				close(PIDF);

				if ($L->get_app_user($app) == $L->whoami() || $L->i_am_root()) {
					my $ret = kill(0, $pid);
					print $ret ? "Online\n" : "Offline\n";
					return 0;
				} else {
					cerr "Not proper user to check status of this application!";
					return 1;
				}
			}
		}
	} else {
		return 1;
	}
}

sub cmd_app_activate {
	my $app = $ARGV[1];

	my $L = new Limerick();
	
	if (! $L->config->success()) {
		cerr "Configuration file is malformed.";
		return 1;
	}

	my $appc = $L->config->for_app($app);
	if (! defined $appc->{'approot'}) {
		cerr "Unable to find '$app'";
		cnotify "Available apps: " . join(", ", keys %{ $L->all_apps });
		return 1;
	} else {
		$appc->{'active'} = \1;
		if ($L->config->rewrite()) {
			cnotify "$app => ON";
			return 0;
		} else {
			cerr "$app toggle failed.";
			return 1;
		}
	}
}

sub cmd_app_deactivate {
	my $app = $ARGV[1];

	my $L = new Limerick();
	
	if (! $L->config->success()) {
		cerr "Configuration file is malformed.";
		return 1;
	}

	my $appc = $L->config->for_app($app);
	if (! defined $appc->{'approot'}) {
		cerr "Unable to find '$app'";
		cnotify "Available apps: " . join(", ", keys %{ $L->all_apps });
		return 1;
	} else {
		$appc->{'active'} = \0;
		if ($L->config->rewrite()) {
			cnotify "$app => OFF";
			return 0;
		} else {
			cerr "$app toggle failed.";
			return 1;
		}

	}
}

sub cmd_app_add { 
	# Copies necessary files into approot to support
	# running with Limerick...

	my $app_path = $ARGV[1];

	my @domain;
	my %opts = (
		'domain=s' => \@domain
	);

	if ($_[0]) {
		my $app_nm = shift @_;
		$app_path = Limerick::get_dir_for_poet_app($app_nm);
	}

	if (ref $_[0]) {
		_cmd_opts(0, shift @_, %opts);
	} else {
		_cmd_opts(2, %opts);
	}

	if (! -d $app_path) {
		cerr "$app_path is not a directory, or is not readable by this user.";
		return 1;
	}

	if (! -f "$app_path/.poet_root") {
		cerr "$app_path does not appear to be a valid Poet application.";
		return 1;
	}

	my $poet_root = `grep app_name $app_path/.poet_root`;

	my ($app_name) = $poet_root =~ m/app_name\:\s+(.*?)$/;
	if (! length $app_name) {
		cerr "Unable to determine application name!";
		return 1;
	}

	my $orig_app_name = $app_name;
	$app_name = lc $app_name; $app_name =~ s/[^a-z0-9_\-\.]//g;

	my $L = new Limerick();
	
	if (! $L->config->success()) {
		cerr "Configuration file is malformed.";
		return 1;
	} else {
		cout "Setting up $app_name...";

		my $overrides = { 'approot' => File::Spec->rel2abs($app_path), 
			  'description' => "Application $app_name",
			  'active' => \0 
		}; 

		if (int @domain) {
			if (int @domain == 1) {
				$overrides->{'hostname'} = $domain[0];
			} else {
				$overrides->{'hostname'} = \@domain;
			}
		}

		my $cloneRet = $L->config->clone_app( '_template' => $app_name, $overrides );

		if (! $cloneRet) {
			cerr "$app_name already in configuration -- or _template is missing. You will need to add by hand.";
		}

		return 1 if !$L->empower_app( $app_path, $orig_app_name );

		$L->config->rewrite();

		return 0;
	}
}

sub cmd_app_new {
	my $app_nm = $ARGV[1];
	my @domain;

	my @O = _cmd_opts(2, 
		'domain=s' => \@domain
	);

	my $app_path = Limerick::get_dir_for_poet_app( $app_nm );

	if (-e $app_path) {
		cerr "$app_path already exists on your filesystem!";
		return 1;
	}

	cout "Running 'poet new'...";
	my @poet_out = `poet new $app_path`;
	if ($? == 0) {
		cout "poet returned OK. Running 'limerick app-add'...";
		return cmd_app_add($app_nm => \@O);
	} else {
		cerr "poet returned NOT OK:";
		print map { "[*] $_"; } @poet_out;
		return 1;
	}
}

sub cmd_app_list {
	my $L = new Limerick();
	
	if (! $L->config->success()) {
		cerr "Configuration file is malformed.";
		return 1;
	}

	foreach my $appK (sort keys %{ $L->all_apps }) {
		my $appc = $L->configData->{'apps'}{$appK};

		cnotify "$appK => " . ($appc->{'active'} && $appK !~ m/^_/ ? "Active" : "Inactive");
	}

	return 0;
}

sub cmd_build {
	my $L = new Limerick();
	
	if (! $L->config->success()) {
		cerr "Configuration file is malformed.";
		return 1;
	} else {
		cout "Everything looks good.";
	}

	my $rc_file_name = "$FindBin::Bin/build/limerick-rc.sh";
	my $mani_file_name = Limerick::_manifestFileName();

	if ($L->build_rc_script( $rc_file_name, $mani_file_name )) {
		cout "RC script build complete.";
	} else {
		cerr "Failed to build RC script.";
	}

	if (my $ret = $L->build_frontend_config()) {
		cout "Frontend build complete.";
		cout "Ensure that '$ret' is included in your core web server configuration.";
	} elsif( defined($ret) ) {
		# We tried.. but we failed.
		cerr "Failed to build frontend configuration.";
	} else {
		# We determined one wasn't needed.
	}
}

sub cmd_test {
	my $app;
	my %opts = _cmd_opts(1, "app=s" => \$app);

	if (-e $app) {
		print Limerick::get_app_user($app);
	} else {
		cexp "X", "no $app!";
	}

	return 0;
}

sub _startupAndParse {
	my $L = new Limerick();
	if (! $L->config->success()) {
		cerr "Configuration file is malformed.";
		return undef;
	} else {
		#cout "Everything looks good.";
		return $L;
	}
}

sub _cmd_opts {
	my $shift_num = shift @_;
	my @use_args;
	if (ref $_[0] eq 'ARRAY') {
		@use_args = @{ shift @_ };
	} else {
		@use_args = @ARGV;

		for (1..$shift_num) {
			shift @use_args;
		}
	}

	my @used = @use_args;

	GetOptionsFromArray(\@use_args, @_);

	return @used;
}
