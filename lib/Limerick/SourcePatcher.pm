package Limerick::SourcePatcher;
use strict;

sub new {
	my $self = bless({}, shift @_);

	$self->{'target'} = shift @_;
	$self->{'dirty'}  = 0;
	$self->{'exists'} = 0;
	$self->{'abort'}  = 0;
	$self->{'finish'} = 0;
	$self->{'src'}    = [];
	$self->{'nsrc'}   = [];
	$self->{'set'}    = {};

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
		chomp;
		push(@src, $_);
	}

	close(SRC);

	$self->{'src'} = \@src;
}

sub set {
	$_[0]->{'set'}{$_[1]} = $_[2];
}

sub unset_all {
	$_[0]->{'set'} = {};
}

sub abort {
	$_[0]->{'abort'} = 1;
}

sub match_line {
	my $self = shift @_;
	my $re_match = shift @_;
	my $cb_match = shift @_;

	$self->{'abort'} = 0; $self->{'finish'} = 0;
	$self->unset_all();

	my $edits = 0;

	foreach my $l (@{ $self->{'src'} }) {
		if ($l =~ m/$re_match/) {
			my $ret = &{ $cb_match }($l, $self);
			if (! $ret) {
				push( @{$self->{'nsrc'}}, $l);
				next;
			} elsif (ref $ret) {
				push( @{$self->{'nsrc'}}, @$ret);
			} else {
				push( @{$self->{'nsrc'}}, $ret);
			}

			$edits++;

			if ($self->{'abort'} || $self->{'finish'}) {
				last;
			}
		} else {
			#print "[.] $l does not match $re_match\n";
			push( @{$self->{'nsrc'}}, $l);
			next;
		}
	}

	if ($self->{'abort'}) { return 0; }

	@{$self->{'src'}}   = @{ $self->{'nsrc'} };
	$self->{'dirty'} = $edits > 0 ? 1 : 0;

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

# Down-checker in-line MW:

#  enable_if { -f $poet->bin_path("tmp/.down") } 
#  		sub { return sub { 
#				my $env = shift @_; 
#				return [ 503, [ ['Content-Type', 'text/html'] ], ["We are down at the moment. Check back soon!"] ]  
#			  } 
#		}
#  ;

1;