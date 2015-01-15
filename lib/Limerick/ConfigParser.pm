package Limerick::ConfigParser;
use strict;

require Storable;

sub new {
	my $class = shift @_;
	my %opts = @_;

	my $self = bless({}, $class);

	$self->{'struct'} = undef;
	$self->{'json_package'} = $self->_detectJSON();
	$self->{'last_fn'} = undef;

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

sub success {
	return ref $_[0]->{'struct'} eq 'HASH';
}

sub struct {
	return $_[0]->{'struct'};
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

	$self->{'last_fn'} = $fn;
	$self->_parseFromDataString( $fdata );
}

sub _parseFromDataString {
	my $self = shift @_;
	my $data = shift @_;

	my $json = $self->{'json_package'}->new();
	my $json_data;

	eval {
		$json_data = $json->pretty->decode( $data );
	};

	if (! $@) {
		$self->{'struct'} = $json_data;
	}
}

sub rewrite {
	my $self = shift;

	return undef if ! $self->{'last_fn'} || ! -w $self->{'last_fn'};

	open(CNF, ">", $self->{'last_fn'});

	my $json = $self->{'json_package'}->new();
	my $out_data;

	eval {
		$out_data = $json->pretty->canonical->encode( $self->{'struct'} );
	};

	if (! $@) {
		print CNF $out_data . "\n";
		close(CNF);

		return 1;
	} else {
		return undef;
	}
}

sub for_app {
	my $self = shift;
	my $tag  = shift;

	return ref $self->struct->{'apps'}{$tag} ? $self->struct->{'apps'}{$tag} : {};
}

sub clone_app {
	my $self = shift;
	my $src  = shift;
	my $dest = shift;
	my $edits = shift || {};

	if (! ref $self->struct->{'apps'}) { return undef; }

	if (! $self->struct->{'apps'}->{$src} || ref $self->struct->{'apps'}->{$dest}) {
		return undef;
	}

	$self->struct->{'apps'}->{$dest} = Storable::dclone( $self->struct->{'apps'}->{$src} );

	return undef unless ref $self->struct->{'apps'}->{$dest};

	if (int keys %$edits) {
		foreach my $k (keys %$edits) {
			$self->struct->{'apps'}->{$dest}->{$k} = $edits->{$k};
		}
	}

	#return $self->rewrite();
	return 1;
}

1;