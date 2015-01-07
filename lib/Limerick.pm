package Limerick;
use strict;

require Limerick::ConfigParser;

sub new {
	return bless({}, shift @_);
}

sub parse {
	my $self = shift;
	my $fn   = shift;

	if (! -f $fn) {
		return undef;
	}

	return new Limerick::ConfigParser( 'file' => $fn );
}









1;