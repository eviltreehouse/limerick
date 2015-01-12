package Limerick::SourcePatcher;
use strict;

sub new {
	my $self = bless({}, shift @_);

	$self->{'target'} = shift @_;
	$self->{'dirty'}  = 0;
	$self->{'exists'} = 0;
	$self->{'src'}    = [];
	$self->{'nsrc'}   = [];

	$self->_load();
	return $self;
}

sub exists {
	return $_[0]->{'exists'};
}

sub _load {
	my $self = shift @_;

	open(SRC, "<", $self->{'target'}) or return;
	$self->{'exists'} = 1;

	my @src;
	while (<SRC>) {
		push(@src, $_);
	}

	close(SRC);

	$self->{'src'} = \@src;
}

sub match_line {
	my $self = shift @_;
	my $re_match = shift @_;
	my $cb_match = shift @_;

	my $edits = 0;

	foreach my $l (@{ $self->{'src'} }) {
		if ($l =~ m/$re_match/) {
			my $ret = &{ $cb_match }($l);
			if (! $ret) {
				push( @{$self->{'nsrc'}}, $l);
				next;
			} elsif (ref $ret) {
				push( @{$self->{'nsrc'}}, @$ret);
			} else {
				push( @{$self->{'nsrc'}}, $ret);
			}

			$edits++;
		} else {
			push( @{$self->{'nsrc'}}, $l);
		}

		$self->{'dirty'} = 1;
		@{$self->{'src'}}   = @{ $self->{'nsrc'} };
	}

	return $edits;
}

sub save {
	my $self = shift @_;
	my $target_fn = int @_ ? shift @_ : $self->{'target'};

	# No edits made..
	if (! $self->{'dirty'}) { return 0; }

	if (! -w $target_fn) {
		return undef;
	} else {
		open(SRC, ">", $target_fn) or return undef;
		foreach my $l (@{ $self->{'nsrc'} }) {
			print SRC $l;
			print SRC "\n";
		}

		close(SRC);
	}

	return 1;
}

1;