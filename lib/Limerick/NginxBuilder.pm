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

  foreach my $appKey ( keys %$active_apps ) {
    push(@conf, $self->http_server_block( $active_apps->{$appKey} ));
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
  my $conf = $tmpl;
  $conf =~ s/\{\{app\}\}/$app->{'app'}/g;
  $conf =~ s/\{\{fbind\}\}/0.0.0.0/g;
  $conf =~ s/\{\{fport\}\}/80/g;
  $conf =~ s/\{\{lbind\}\}/127.0.0.1/g;
  $conf =~ s/\{\{lport\}\}/$app->{'port'}/g;

  return $conf;
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