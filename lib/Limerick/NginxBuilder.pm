package Limerick::NginxBuilder;
use strict;

sub new {
  my $class = shift @_;

  my $self = bless({}, $class);

  $self->{'Limerick'} = shift @_;

  return $self;
}

sub configData {
  return $_[0]->{'Limerick'}->configData;
}

sub config {
  return $_[0]->{'Limerick'}->config;
}

sub conf_filename {
	return "$FindBin::Bin/build/limerick-nginx.conf";
}

sub build {
  my $self = shift;
  my $active_apps = shift;

  my @conf;

  my $cfg = $self->configData;

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


  foreach my $appKey ( keys %$active_apps ) {
    my $app = $active_apps->{$appKey};
    if ($app->{'bind'}) {
      $app->{'fbind'} = $cfg->{'interfaces'}{$app->{'bind'}};
      if (! $app->{'fbind'}) {
        $app->{'fbind'} = $default_interface_host;
      }
    } else {
    	$app->{'fbind'} = $default_interface_host;
    }

    $app->{'fport'} = $app->{'ssl'} ? '443' : '80';
    $app->{'server_names'} = $self->_generateServerNameString( $app );
    if (! $app->{'server_names'}) {
    	$app->{'server_names'} = $appKey;
    }

    $app->{'app'} = $appKey;

    push(@conf, $app->{'ssl'} ? $self->https_server_block( $app ) : $self->http_server_block( $app ));
  }

  open(CNF, ">", $self->conf_filename) or return undef;
  print CNF join("\n", @conf);
  close(CNF);

  return 1;
}

sub http_server_block {
  my $app = $_[1];

  my $tmpl = <<EOT

  # {{app}}
  http {
    server {
      listen {{fbind}}:{{fport}};
      server_name {{servernames}};

	  location ~ /\. { return 404; }

      location / {
        set \$script "";
        set \$path_info \$uri;
        fastcgi_pass {{lbind}}:{{lport}};
        fastcgi_param  SCRIPT_NAME      \$script;
        fastcgi_param  PATH_INFO        \$path_info;
        fastcgi_param  QUERY_STRING     \$query_string;
        fastcgi_param  REQUEST_METHOD   \$request_method;
        fastcgi_param  CONTENT_TYPE     \$content_type;
        fastcgi_param  CONTENT_LENGTH   \$content_length;
        fastcgi_param  REQUEST_URI      \$request_uri;
        fastcgi_param  SERVER_PROTOCOL  \$server_protocol;
        fastcgi_param  REMOTE_ADDR      \$remote_addr;
        fastcgi_param  REMOTE_PORT      \$remote_port;
        fastcgi_param  SERVER_ADDR      \$server_addr;
        fastcgi_param  SERVER_PORT      \$server_port;
        fastcgi_param  SERVER_NAME      \$server_name;
      }
    }
  }

EOT
;

	return _interp_block($tmpl, $app);
}

sub https_server_block {
  my $app = $_[1];

  my $tmpl = <<EOT

  # {{app}}
  http {
    server {
      listen {{fbind}}:{{fport}};
      server_name {{servernames}};

	  location ~ /\. { return 404; }

	  ssl on
	  ssl_certificate {{cert}}
	  ssl_certificate_key {{cert_key}}

      location / {
        set \$script "";
        set \$path_info \$uri;
        fastcgi_pass {{lbind}}:{{lport}};
        fastcgi_param  SCRIPT_NAME      \$script;
        fastcgi_param  PATH_INFO        \$path_info;
        fastcgi_param  QUERY_STRING     \$query_string;
        fastcgi_param  REQUEST_METHOD   \$request_method;
        fastcgi_param  CONTENT_TYPE     \$content_type;
        fastcgi_param  CONTENT_LENGTH   \$content_length;
        fastcgi_param  REQUEST_URI      \$request_uri;
        fastcgi_param  SERVER_PROTOCOL  \$server_protocol;
        fastcgi_param  REMOTE_ADDR      \$remote_addr;
        fastcgi_param  REMOTE_PORT      \$remote_port;
        fastcgi_param  SERVER_ADDR      \$server_addr;
        fastcgi_param  SERVER_PORT      \$server_port;
        fastcgi_param  SERVER_NAME      \$server_name;
      }
    }
  }

EOT
;

  return _interp_block($tmpl, $app);
}

sub _interp_block {
	my $conf = shift @_;
	my $app  = shift @_;

	$conf =~ s/\{\{app\}\}/$app->{'app'}/g;
	$conf =~ s/\{\{fbind\}\}/$app->{'fbind'}/g;
	$conf =~ s/\{\{fport\}\}/$app->{'fport'}/g;
	$conf =~ s/\{\{lbind\}\}/127.0.0.1/g;
	$conf =~ s/\{\{lport\}\}/$app->{'port'}/g;
	$conf =~ s/\{\{servernames\}\}/$app->{'server_names'}/g;

	$conf =~ s/\{\{cert\}\}/$app->{'ssl_certificate'}/g;
	$conf =~ s/\{\{cert_key\}\}/$app->{'ssl_certificate_key'}/g;

	return $conf;	
}


sub _generateServerNameString {
	my $self = shift;
	my $app  = shift;

	if (! $app->{'hostname'}) {
		# Use appKey instead..
		return undef;
	} else {
		if (ref $app->{'hostname'} eq 'ARRAY') {
			return join(" ", @{$app->{'hostname'}});
		} else {
			return $app->{'hostname'};
		}
	}
}

1;


__END__

server {

listen   443;

ssl    on;
ssl_certificate    /etc/ssl/your_domain_name.pem; (or bundle.crt)
ssl_certificate_key    /etc/ssl/your_domain_name.key;

server_name your.domain.com;
access_log /var/log/nginx/nginx.vhost.access.log;
error_log /var/log/nginx/nginx.vhost.error.log;
location / {
root   /home/www/public_html/your.domain.com/public/;
index  index.html;
}

} 