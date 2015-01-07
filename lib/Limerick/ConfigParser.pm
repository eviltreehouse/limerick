package Limerick::ConfigParser;
use strict;

sub new {
	my $class = shift @_;
	my %opts = @_;

	my $self = bless({}, $class);

	$self->{'struct'} = {};
	$self->{'json_package'} = $self->_detectJSON();

	if (! $self->{'json_package'}) {
		die "No JSON parser support. Install JSON::XS or JSON";
	}

	if ($opts{'file'}) {
		$self->_parseFromFile( $opts{'file'} );
	} elsif ($opts{'data'}) {
		$self->_parseFromDataString( $opts{'data'} );
	}

	return $self;
}

sub _detectJSON {
	my @possible_libs = qw/JSON/;

	foreach my $lib (@possible_libs) {
		eval "require $lib;";
		if ($@) {
			next;
		} else {
			return $lib;
		}
	}
}

sub _parseFromFile {
	my $self = shift @_;
	my $fn = shift @_;

	if (! -f $fn) {
		return;
	}

	my $fdata;
	{ local $/ = undef; local *FILE; open FILE, "<$fn"; $fdata = <FILE>; close FILE }

	$self->_parseFromDataString( $fdata );
}

sub _parseFromDataString {
	my $self = shift @_;
	my $data = shift @_;

	my @lines = split(/\r?\n/, $data);

	@lines = map { s/^\s+//g } @lines;
	@lines = map { s/\s+$//g } @lines;

	my $json = $self->{'json_package'}->new();
	my $json_data = $json->decode( join("\n", @lines) );

	$self->{'struct'} = $json_data;
}



1;