package Limerick;
use strict;

require Limerick::ConfigParser;
require Limerick::RCBuilder;

sub new {
	my $self = bless({}, shift @_);

	$self->{'config'} = $self->parse( $self->_configFileName() );
	return $self;
}

sub _configFileName {
	return "$FindBin::Bin/limerick-config.json";
}

sub config {
	return $_[0]->{'config'};
}

sub configData {
	return $_[0]->config->struct;
}

sub parse {
	my $self = shift;
	my $fn   = shift;

	return new Limerick::ConfigParser( 'file' => $fn );
}

sub build_rc_script {
	my $self = shift @_;
	my $b = new Limerick::RCBuilder( $self );

	return $b->build( @_ );
}


1;