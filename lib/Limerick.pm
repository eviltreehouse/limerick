package Limerick;
use strict;

require Limerick::ConfigParser;

sub new {
	my $self = bless({}, shift @_);

	$self->{'config'} = $self->parse( $self->_configFileName() );

	$self->{'last_port'} = undef;

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

sub _init_ports {
	my $self = shift;
	$self->{'last_port'} = undef;

	if (! ref($self->configData->{'ports'})) {
		print STDERR "[!] No port range defined in configuration! (ports.low / ports.high)\n";
		return undef;
	}

	$self->{'port_low'}  = $self->configData->{'ports'}->{'low'};
	$self->{'port_high'} = $self->configData->{'ports'}->{'high'};

	return 1;
}

sub _next_port {
	my $self = shift;

	if (! defined($self->{'last_port'})) {
		$self->{'last_port'} = $self->{'port_low'};
		return $self->{'port_low'};
	} elsif ($self->{'last_port'} == $self->{'port_high'}) {
		return undef;
	} else {
		return ++$self->{'last_port'};
	}
}

sub build_rc_script {
	my $self = shift @_;
	my $rcfn = shift @_;

	if (! $self->config->success) {
		return undef;
	}

	if (! $self->_init_ports()) {
		return undef;
	}

	my $fail = 0;
	open(RCF, ">", "$rcfn") or $fail++;
	return undef if $fail;

	my $cfg = $self->config->struct;

	if (! $cfg->{'apps'}) {
		return undef;
	}

	if (! $cfg->{'shell'}) {
		# Sensible default..
		$cfg->{'shell'} = "/bin/sh";
	}

	print RCF $self->rc_start_header( $cfg->{'as_root'} => $cfg->{'shell'} );

	foreach my $appK ( keys %{ $cfg->{'apps'} }) {
		my $app = $cfg->{'apps'}{$appK};
		$app->{'port'} = $self->_next_port();
		if (! $app->{'port'}) {
			print STDERR "[!] No port available for $appK.\n";
			next;
		}

		if ($appK =~ m/^_/ || (! $app->{'active'})) {
			# Skip apps beginning with _ or are non-active.
			next;
		} else {
			if ($cfg->{'as_root'} && $app->{'user'}) {
				# We can use sudo mode...
			} else {
				# Otherwise throw away the key so we don't even attempt it.
				delete $app->{'user'};
			}

			$app->{'shell'} = $cfg->{'shell'};
			print RCF $self->rc_app_start_block( $appK => $app );
		}
	}

	print RCF $self->rc_start_footer();

	print RCF $self->rc_stop_header();

	foreach my $appK ( keys %{ $cfg->{'apps'} }) {
		my $app = $cfg->{'apps'}{$appK};

		if ($appK =~ m/^_/ || (! $app->{'active'})) {
			# Skip apps beginning with _ or are non-active.
			next;
		} else {
			print RCF $self->rc_app_stop_block( $appK => $app );
		}
	}

	print RCF $self->rc_stop_footer();

	print RCF $self->rc_handler();

	close(RCF);

	chmod 0755, $rcfn;

	return 1;
}

# @FIXME maybe support non-root users?
##!/bin/bash
#whoami
#sudo -u someuser bash << EOF
#echo "In"
#whoami
#EOF
#echo "Out"
#whoami

sub rc_app_start_block {
	my $self = shift;
	my $appName = shift;
	my $opts = shift;

	(my $customenv, my $ucustomenv) = $self->_build_env( $opts->{'env'} );

	my $local_tmpl = <<EOT
	 # {{app}}
	 echo "[.] Starting {{app}}";
	 cd {{appRoot}}/bin
	 export LIMERICK_SERVER_PORT={{port}}
	 export LIMERICK_LAYER={{mode}}
	 export LIMERICK_SERVER_LIB={{server}}
{{customenv}}
	 ./run.pl &
	 echo \$! > {{appRoot}}/bin/tmp/run.pid
	 unset LIMERICK_SERVER_PORT
	 unset LIMERICK_LAYER
	 unset LIMERICK_SERVER_LIB
{{ucustomenv}}
EOT
;

	my $sudo_tmpl = <<EOT
	 # {{app}}
	 echo "[.] Starting {{app}}";
	 cd {{appRoot}}/bin
	 sudo -u {{user}} {{shell}} << CMD
	 export LIMERICK_SERVER_PORT={{port}}
	 export LIMERICK_LAYER={{mode}}
	 export LIMERICK_SERVER_LIB={{server}}
{{customenv}}
	 ./run.pl &
	 echo \\\$! > {{appRoot}}/bin/tmp/run.pid
	 unset LIMERICK_SERVER_PORT
	 unset LIMERICK_LAYER
	 unset LIMERICK_SERVER_LIB
{{ucustomenv}}
CMD
EOT
;
	my $ret = $opts->{'user'} ? $sudo_tmpl : $local_tmpl;

	$ret =~ s/\{\{app\}\}/$appName/g;
	$ret =~ s/\{\{appRoot\}\}/$opts->{'appRoot'}/g;
	$ret =~ s/\{\{port\}\}/$opts->{'port'}/g;
	$ret =~ s/\{\{mode\}\}/$opts->{'mode'}/g;
	$ret =~ s/\{\{user\}\}/$opts->{'user'}/g;
	$ret =~ s/\{\{shell\}\}/$opts->{'shell'}/g;
	$ret =~ s/\{\{server\}\}/$opts->{'server'}/g;
	$ret =~ s/\{\{customenv\}\}/$customenv/;
	$ret =~ s/\{\{ucustomenv\}\}/$ucustomenv/;

	return $ret;
}

sub rc_app_stop_block {
	my $self = shift;
	my $appName = shift;
	my $opts = shift;

	my $tmpl = <<EOT
	# {{app}}
	 kpid=\$(cat {{appRoot}}/bin/tmp/run.pid 2>/dev/null)
	 if [ "\$?" -ne "0" ]
	 then
	  continue
	 fi
	 if [ "\$kpid" -ne "0" ]
	 then
	  echo "[.] Killing {{app}} / PID \$kpid"
	  kill \$kpid	  
	  rm -f {{appRoot}}/bin/tmp/run.pid
	 fi

EOT
;

	my $ret = $tmpl;
	$ret =~ s/\{\{app\}\}/$appName/g;
	$ret =~ s/\{\{appRoot\}\}/$opts->{'appRoot'}/g;

	return $ret;
}

sub rc_start_header {
	my $as_root = $_[1] ? 1 : 0;
	my $shell   = $_[2];

	if ($as_root) {
	return <<EOB;
#!$shell
#
# Note this file is manually generated -- do not edit!
#

if [ "\$(id -u)" != "0" ]; then
    echo "This script must be run as root" 1>&2
    id -u 1>&2
    exit 1
fi

start() {	
EOB
;
	} else {
	return <<EOB;
#!$shell
#
# Note this file is manually generated -- do not edit!
#

start() {	
EOB
;	
	}
}

sub rc_start_footer {
	return <<EOB;
}

EOB
;
}

sub rc_stop_header {
	return <<EOB;

stop() {
EOB
;
}

sub rc_stop_footer {
	return <<EOB;

}

EOB
;
}


sub rc_handler {
	return <<EOB;

case \"\$1\" in
	start)
              	start
		exit 0
        ;;
	stop)
             	stop
		exit 0
        ;;
	*)
          	echo "Usage: limerick start|stop"
                exit 1
        ;;
esac

EOB
;
}

sub _build_env {
	my $self = shift @_;
	my $r_env = shift @_;
	my @env; my @uenv;

	if (ref $r_env) {
		foreach my $ek (keys %{ $r_env }) {
			my $safe_ek = $ek;
			$safe_ek = uc $safe_ek;
			$safe_ek =~ s/[^A-Z0-9_]/_/g;
			push(@env, "\texport $safe_ek=" . $r_env->{$ek});
			push(@uenv, "\tunset $safe_ek");
		}
	}

	return ( join("\n", @env), join("\n", @uenv) );
}


1;