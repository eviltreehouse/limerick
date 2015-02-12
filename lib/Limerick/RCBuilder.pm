package Limerick::RCBuilder;
use strict;

require File::Spec;
require JSON;

sub new {
	my $self = bless({}, $_[0]);

	$self->{'Limerick'} = $_[1];
	$self->{'last_port'} = undef;
	$self->{'port_available'} = {};
	$self->{'manifest'}  = {};

	$self->{'port_ranges'} = [];

	return $self;
}

sub config {
	return $_[0]->{'Limerick'}->config;
}

sub configData {
	return $_[0]->{'Limerick'}->configData;
}

sub _init_ports {
	my $self = shift;
	$self->{'last_port'} = undef;

	if (! ref($self->configData->{'ports'})) {
		print STDERR "[!] No port range defined in configuration! (ports.low / ports.high)\n";
		return undef;
	}

	if (ref $self->configData->{'ports'} eq 'ARRAY') {
		foreach my $pr ( @{$self->configData->{'ports'}} ) {
			push(
			 @{ $self->{'port_ranges'} },
			 [ $pr->{'low'}, $pr->{'high'} ]
			);
		}
	} else {
		$self->{'port_ranges'}[0] = [ $self->configData->{'ports'}->{'low'}, $self->configData->{'ports'}->{'high'} ];
	}

	foreach my $pr (@{ $self->{'port_ranges'} }) {
		for ( $pr->[0] .. $pr->[1] ) {
			$self->{'port_available'}{$_} = 1;
		}
	}

	return 1;
}

sub _next_port {
	my $self = shift;

	my @avail_ports = grep { $self->{'port_available'}{$_} == 1 ? $_ : undef } sort keys %{ $self->{'port_available'} };

	if (int @avail_ports) {
		my $np = shift @avail_ports;
		$self->{'last_port'} = $np;
		$self->{'port_available'}{$np} = 0;
		return $np;
	}

	return undef;
}

sub build {
	my $self = shift @_;
	my $rcfn = shift @_;
	my $manifestfn = shift @_;

	if (! $self->config->success) {
		return undef;
	}

	if (! $self->_init_ports()) {
		return undef;
	}

	my $fail = 0;
	open(RCF, ">", "$rcfn") or $fail++;
	return undef if $fail;

	my $cfg = $self->configData;

	if (! $cfg->{'apps'}) {
		return undef;
	}

	if (! $cfg->{'shell'}) {
		# Sensible default..
		$cfg->{'shell'} = "/bin/sh";
	}

	if (! $cfg->{'interfaces'}) {
		# Setup default interfaces pool.
		$cfg->{'interfaces'} = {
			'any' => '0.0.0.0',
			'default' => 'any'
		};
	}

	my $default_interface;

	if (! $cfg->{'interfaces'}{ $cfg->{'interfaces'}{'default'} }) {
		# Missing default, use first defined.
		delete $cfg->{'interfaces'}{'default'};
		my @infs = keys %{ $cfg->{'interfaces'} };
		$default_interface = $infs[0];
	} else {
		$default_interface = $cfg->{'interfaces'}{'default'};
	}

	my $default_interface_host = $cfg->{'interfaces'}{ $default_interface };

	print RCF $self->rc_start_header( $cfg->{'as_root'} => $cfg->{'shell'} );

	foreach my $appK ( keys %{ $cfg->{'apps'} }) {
		my $app = $cfg->{'apps'}{$appK};

		if ($appK =~ m/^_/ || (! $app->{'active'})) {
			# Skip apps beginning with _ or are non-active.
			next;
		} else {

			my $arcf = _get_apprc_fn( $rcfn => "app.$appK-rc.sh" );
			open(ARCF, ">", $arcf) or return undef;
			print ARCF $self->rc_start_header( $cfg->{'as_root'} => $cfg->{'shell'} );

			$app->{'port'} = $self->_next_port();
			if (! $app->{'port'}) {
				print STDERR "[!] No port available for $appK.\n";
				next;
			}

			if ($cfg->{'as_root'} && $app->{'user'}) {
				# We can use sudo mode...
			} else {
				# Otherwise throw away the key so we don't even attempt it.
				delete $app->{'user'};
			}

			if ($app->{'bind'}) {
				$app->{'host'} = $cfg->{'interfaces'}{ $app->{'bind'} };
				if (! $app->{'host'}) {
					$app->{'host'} = $default_interface_host;
				}
			} else {
				$app->{'host'} = $default_interface_host;
			}

			if (ref $app->{'permissions'}) {
				my @perms;
				if (ref $app->{'permissions'} eq 'HASH') {
					push (@perms, $app->{'permissions'});
				} elsif (ref $app->{'permissions'} eq 'ARRAY') {
					push (@perms, @{ $app->{'permissions'}});
				}

				print RCF "\t# $appK Permissions Settings\n";
				print ARCF "\t# Permissions Settings\n";
				foreach my $perm (@perms) {
					next unless $perm->{'directory'};

					# Don't permit anything lower than app-root...
					$perm->{'directory'} =~ s/\.\././g;

					my $target = File::Spec->catdir($app->{'approot'}, $perm->{'directory'});
					my $user = $app->{'user'} ? $app->{'user'} : undef;

					my $recursive = ($perm->{'recurse'} || $perm->{'recursive'}) ? "-R" : "";

					if ($perm->{'chown'}) {
						if ($user) {
							print RCF "\tchown $recursive $user $target 2>/dev/null\n";
						}
					}

					if ($perm->{'chgrp'}) {
						my $grp = $perm->{'chgrp'};
						$grp =~ s/[^0-9A-Z_]//g;
						if ($user) {
							print RCF "\tchgrp $recursive $grp $target 2>/dev/null\n";
						}
					}

					if ($perm->{'chmod'}) {
						my $chmod = $perm->{'chmod'};
						$chmod =~ s/[^0-9ugosrwx\+\-]//g;
						print RCF "\tchmod $recursive $chmod $target 2>/dev/null\n";
					}
				}

				print RCF "\t\#\n\n";
				print ARCF "\t\#\n\n";
			}

			$self->{'manifest'}{$appK} = { 'host' => $app->{'host'}, 'lport' => $app->{'port'}, 'user' => $app->{'user'} || undef };

			$app->{'shell'} = $cfg->{'shell'};
			print RCF $self->rc_app_start_block( $appK => $app );
			print ARCF $self->rc_app_start_block( $appK => $app );

			print ARCF $self->rc_start_footer();
			print ARCF $self->rc_stop_header();
			print ARCF $self->rc_app_stop_block( $appK => $app );
			print ARCF $self->rc_stop_footer();
			print ARCF $self->rc_handler($arcf);
			close (ARCF);
			chmod 0755, $arcf;
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

	return $self->write_manifest( $manifestfn );
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
	 cd {{approot}}/bin
	 echo {{port}} > tmp/app.port
	 export LIMERICK_SERVER_PORT={{port}}
	 export LIMERICK_LAYER={{mode}}
	 export LIMERICK_SERVER_LIB={{server}}
{{customenv}}
	 ./run.pl &
	 echo \$! > {{approot}}/bin/tmp/run.pid
	 unset LIMERICK_SERVER_PORT
	 unset LIMERICK_LAYER
	 unset LIMERICK_SERVER_LIB
{{ucustomenv}}
EOT
;

	my $sudo_tmpl = <<EOT
	 # {{app}}
	 echo "[.] Starting {{app}}";
	 cd {{approot}}/bin
	 sudo -u {{user}} {{shell}} << CMD
	 echo {{port}} > tmp/app.port
	 export LIMERICK_SERVER_PORT={{port}}
	 export LIMERICK_LAYER={{mode}}
	 export LIMERICK_SERVER_LIB={{server}}
{{customenv}}
	 ./run.pl &
	 echo \\\$! > {{approot}}/bin/tmp/run.pid
	 unset LIMERICK_SERVER_PORT
	 unset LIMERICK_LAYER
	 unset LIMERICK_SERVER_LIB
{{ucustomenv}}
CMD
EOT
;
	my $ret = $opts->{'user'} ? $sudo_tmpl : $local_tmpl;

	$ret =~ s/\{\{app\}\}/$appName/g;
	$ret =~ s/\{\{approot\}\}/$opts->{'approot'}/g;
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
	 kpid=\$(cat {{approot}}/bin/tmp/run.pid 2>/dev/null)
	 if [ "\$?" -ne "0" ]
	 then
	  continue
	 fi
	 if [ "\$kpid" -ne "0" ]
	 then
	  echo "[.] Killing {{app}} / PID \$kpid"
	  kill \$kpid	  
	  rm -f {{approot}}/bin/tmp/run.pid
	  rm -f {{approot}}/bin/tmp/app.port
	 fi

EOT
;

	my $ret = $tmpl;
	$ret =~ s/\{\{app\}\}/$appName/g;
	$ret =~ s/\{\{approot\}\}/$opts->{'approot'}/g;

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
	shift @_ if ref $_[0];

	my $hndl = int @_ ? shift @_ : 'limerick';
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
          	echo "Usage: $hndl start|stop"
                exit 1
        ;;
esac

EOB
;
}

sub write_manifest {
	my $self = shift;
	my $manfn = shift;

	my $json = new JSON();

	open(MANF, ">", $manfn) or return undef;
	print MANF $json->pretty->canonical->encode( $self->{'manifest'} );
	close(MANF);

	undef $json;

	return 1;
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

sub _get_apprc_fn {
	my $rcfn = shift @_;
	my $fn   = shift @_;

	my @v = File::Spec->splitpath( $rcfn );

	return File::Spec->catfile( $v[1], $fn );
}

1;