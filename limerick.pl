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
	'build' => \&cmd_build,
	'test'  => \&cmd_test
);

if (! $commands{ lc $ARGV[0] }) {
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

sub cmd_app_add { 
	# Copies necessary files into approot to support
	# running with Limerick...

	my $app_path = $ARGV[1];

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

		my $cloneRet = $L->config->clone_app( '_template' => $app_name, 
			{ 'approot' => File::Spec->rel2abs($app_path), 
			  'description' => "Application $app_name",
			  'active' => \0 
			} 
		);

		if (! $cloneRet) {
			cerr "$app_name already in configuration -- or _template is missing. You will need to add by hand.";
		}

		return 1 if !$L->empower_app( $app_path, $orig_app_name );

		$L->config->rewrite();

		return 0;
	}
}

sub cmd_app_new {
	my %o;
	_cmd_opts(1, 
		'string=s' => \$o{'s'}
	);

	print "[X] Not implemented.\n";
	print $o{'s'} . "\n";
	return 1;
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

sub _cmd_opts {
	my $shift_num = shift @_;
	my @use_args = @ARGV;
	for (1..$shift_num) {
		shift @use_args;
	}

	GetOptionsFromArray(\@use_args, @_);
}
