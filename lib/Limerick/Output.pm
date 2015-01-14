package Limerick::Output;
use strict;

use base qw/Exporter/;

$| = 1;
our @EXPORT = qw/cout cerr cwarn cnotify cexp/;

sub cout($) {
	print "[.] " . $_[0];
	print "\n";
}

sub cerr($) {
	print STDERR "[!] " . $_[0];
	print STDERR "\n";
}

sub cwarn($) {
	print "[X] " . $_[0];
	print "\n";
}

sub cnotify($) {
	print "[+] " . $_[0];
	print "\n";
}

sub cexp($$) {
	print "[" . $_[0] . "] " . $_[1];
	print "\n";
}