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

sub apps {
	return $_[0]->configData->{'apps'} || {};
}

sub active_apps {
	my $self = shift;
	my %ret;

	foreach my $appKey (keys %{ $self->apps }) {
		next if $appKey =~ m/^_/;
		next if (! $self->apps->{$appKey}{'active'});

		$ret{$appKey} = $self->apps->{$appKey};
	}

	return \%ret;
}

sub build_frontend_config {
	my $self = shift;

	my %supported = map { $_ => 1 } supported_frontends();
	if ( $supported{ lc $self->configData->{'frontend'}} ) {
		my $module = ucfirst(lc($self->configData->{'frontend'})) . 'Builder';
		$module = "Limerick\::$module";
		my $builder;

		eval "require $module;";
		if ($@) { 
			print STDERR $@;
			return 0; 
		}

		eval {
			$builder = $module->new($self);
		};

		if ($@) { return 0; }
		if (! ref $builder) { return 0; }

		return $builder->build( $self->active_apps ) ? 1 : 0;
	} else {
		if (! $self->{'configData'}->{'frontend'}) {
			# Don't care.
			return undef;
		} else {
			print "[!] " . $self->{'configData'}{'frontend'} . " is not a supported frontend!\n";
			return 0;
		}
	}
}

sub supported_frontends {
	return qw/nginx/;
}


1;