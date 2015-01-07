#!/usr/bin/env perl
use strict;
use FindBin;

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
	'app'   => \&cmd_app,
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

sub cmd_app { 
	# Copies necessary files into appRoot to support
	# running with Limerick...

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

	my $rc_file_name = "$FindBin::Bin/limerick-rc.sh";

	if ($L->build_rc_script( $rc_file_name )) {
		print "[.] Script build complete.\n";
	} else {
		print "[!] Failed to build script.\n";
	}

}