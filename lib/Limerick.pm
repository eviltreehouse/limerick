package Limerick;
use strict;

require Limerick::ConfigParser;

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

sub parse {
	my $self = shift;
	my $fn   = shift;

	return new Limerick::ConfigParser( 'file' => $fn );
}

sub build_rc_script {
	my $self = shift @_;
	my $rcfn = shift @_;

	if (! $self->config->success) {
		return undef;
	}

	my $fail = 0;
	open(RCF, ">", "$rcfn") or $fail++;
	return undef if $fail;

	my $cfg = $self->config->struct;

	if (! $cfg->{'apps'}) {
		return undef;
	}

	print RCF $self->rc_start_header();

	foreach my $appK ( keys %{ $cfg->{'apps'} }) {
		my $app = $cfg->{'apps'}{$appK};

		if ($appK =~ m/^_/ || (! $app->{'active'})) {
			# Skip apps beginning with _ or are non-active.
			next;
		} else {
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

	my $tmpl = <<EOT
	 # {{app}}
	 echo "[.] Starting {{app}}";
	 cd {{appRoot}}/bin
	 ./run.pl &
	 echo \$! > tmp/run.pid

EOT
;
	my $ret = $tmpl;
	$ret =~ s/\{\{app\}\}/$appName/g;
	$ret =~ s/\{\{appRoot\}\}/$opts->{'appRoot'}/g;

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
	return <<EOB;
#!/bin/bash
#
# Note this file is manually generated -- do not edit!
#

start() {	
EOB
;
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



1;