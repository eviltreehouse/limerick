#!/usr/bin/env perl
use strict;
use FindBin;
require File::Spec;

use lib "$FindBin::Bin/lib";
require Limerick;

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
	'build' => \&cmd_build
);

if (! $commands{ lc $ARGV[0] }) {
	print "Supported commands are: " . join(", ", sort keys %commands) . "\n";
	exit 1;
} else {
	exit &{ $commands{ lc $ARGV[0] } }( @ARGV );
}

sub cmd_setup {
	my $skel_file = "$FindBin::Bin/skel/limerick-config.json-dist";
	my $dest_file = "$FindBin::Bin/limerick-config.json";

	if (! -f $skel_file) {
		print "[!] Skeleton configuration does not exist!\n";
		return 1;
	} elsif (-f $dest_file) {
		print "[!] limerick-config.json already exists! Move it out of the way first.\n";
		return 1;
	}

	`cp $skel_file $dest_file 2>/dev/null`;
	if ($? != 0) {
		print "[!] Unable to write to $dest_file. Ensure you have permissions.\n";
		return 1;
	}

	print "[.] Base configuration file written successfully.\n";
	return 0;
}

sub cmd_app_add { 
	# Copies necessary files into appRoot to support
	# running with Limerick...

	my $app_path = $ARGV[1];

	if (! -d $app_path) {
		print "[!] $app_path is not a directory, or is not readable by this user.\n";
		return 1;
	}

	if (! -f "$app_path/.poet_root") {
		print "[!] $app_path does not appear to be a valid Poet application.\n";
		return 1;
	}

	my $poet_root = `grep app_name $app_path/.poet_root`;

	my ($app_name) = $poet_root =~ m/app_name\:\s+(.*?)$/;
	if (! length $app_name) {
		print "[!] Unable to determine application name!\n";
		return 1;
	}

	$app_name = lc $app_name; $app_name =~ s/[^a-z0-9_]//g;

	my $L = new Limerick();
	
	if (! $L->config->success()) {
		print "[!] Configuration file is malformed.\n";
		return 1;
	} else {
		print "[.] Setting up $app_name...\n";

		my $cloneRet = $L->config->clone_app( '_template' => $app_name, { 'appRoot' => File::Spec->canonpath($app_path), 'description' => "Application $app_name" } );
		if (! $cloneRet) {
			print "[!] $app_name already in configuration -- or _template is missing. You will need to add by hand.\n";
		}

		return 1 if !$L->empower_app( $app_path );

		return 0;
	}
}

sub cmd_app_new {
	print "[X] Not implemented.\n";
	return 1;
}

sub cmd_build {
	my $L = new Limerick();
	
	if (! $L->config->success()) {
		print "[!] Configuration file is malformed.\n";
		return 1;
	} else {
		print "[.] Everything looks good.\n";
	}

	my $rc_file_name = "$FindBin::Bin/build/limerick-rc.sh";
	my $mani_file_name = "$FindBin::Bin/build/limerick-apps.json";

	if ($L->build_rc_script( $rc_file_name, $mani_file_name )) {
		print "[.] RC script build complete.\n";
	} else {
		print "[!] Failed to build RC script.\n";
	}

	if (my $ret = $L->build_frontend_config()) {
		print "[.] Frontend build complete.\n";
	} elsif( defined($ret) ) {
		# We tried.. but we failed.
		print "[!] Failed to build frontend configuration.\n";
	} else {
		# We determined one wasn't needed.
	}

}