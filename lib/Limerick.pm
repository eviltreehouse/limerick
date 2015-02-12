package Limerick v0.9.1;
use strict;

require Limerick::ConfigParser;
require Limerick::ManifestParser;

use Limerick::Output;

require Limerick::RCBuilder;
require Limerick::SourcePatcher;
require File::Spec;

my @APPFILES = (
	[ 'skel/LimerickPoweredConf.pm-dist', 'lib/LimerickPowered', 'lib/LimerickPowered/Conf.pm' ],
	[ 'skel/LimerickPoweredServer.pm-dist', 'lib/LimerickPowered', 'lib/LimerickPowered/Server.pm' ],
	[ 'skel/LimerickPoweredImport.pm-dist', 'lib/LimerickPowered', 'lib/LimerickPowered/Import.pm' ],
);

sub new {
	my $self = bless({}, shift @_);

	$self->{'config'} = $self->parse( $self->_configFileName(), 'ConfigParser' );
	$self->{'manifest'} = $self->parse( $self->_manifestFileName(), 'ManifestParser' );

	$self->{'root'} = i_am_root();

	return $self;
}

sub _configFileName {
	return "$FindBin::Bin/limerick-config.json";
}

sub _manifestFileName {
	return "$FindBin::Bin/build/limerick-apps.json";
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
	my $bc   = shift || "ConfigParser";

	$bc = "Limerick\:\:$bc";

	return $bc->new( 'file' => $fn );
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

sub all_apps {
	my $self = shift;
	my %ret;

	foreach my $appKey (keys %{ $self->apps }) {
		next if $appKey =~ m/^_template/;

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

		my $ret = $builder->build( $self->active_apps );
		return $ret ? $ret : 0;
	} else {
		if (! $self->{'configData'}->{'frontend'}) {
			# Don't care.
			return undef;
		} else {
			cerr "[!] " . $self->{'configData'}{'frontend'} . " is not a supported frontend!";
			return 0;
		}
	}
}

sub supported_frontends {
	return qw/nginx/;
}

sub empower_app {
	my $self = shift;
	my $app_dir = shift;
	my $app_name = shift;

	my $app_user = get_app_user($app_dir);
	my $app_grp  = get_app_group($app_dir);

	if ( ! $self->{'root'} ) {
		if (! -w $app_dir) {
			cerr "$app_dir is not writable by current user.";
			return undef;
		}

		if (! -w "$app_dir/lib/$app_name") {
			cerr "$app_dir/lib/$app_name is not writable by current user.";
			return undef;
		}
	} else {
		cout "I am ROOT: support files will be CHOWNd to '" . $app_user . ":$app_grp'";
	}

	foreach my $file (@APPFILES) {
		my $src = join("/", "$FindBin::Bin", $file->[0]);
		my $destdir = join("/", $app_dir, $file->[1]);
		my $dest = join("/", $app_dir, $file->[2]);

		`mkdir -p $destdir`;
		return undef if $? > 0;

		if ($self->{'root'}) {
			`chown $app_user:$app_grp $destdir`;
			return undef if $? > 0;
		}

		`cp $src $dest 2>/dev/null`;
		return undef if $? > 0;

		if ($self->{'root'}) {
			`chown $app_user:$app_grp $dest`;
			return undef if $? > 0;
		}

		print "[+] $src => $dest\n";
	}

	if (-f "$app_dir/lib/$app_name/Conf.pm") {
		my $patcher = new Limerick::SourcePatcher( "$app_dir/lib/$app_name/Conf.pm" );
		my $pret    = $patcher->match_line("extends\\s+['\"]Poet\:\:Conf['\"]\\s*;", sub {
			#print "!MATCHER!\n";
			my $orig = shift @_;
			return undef if $orig =~ m/^\s*\#/;
			return [
				"# Limerick altered your base library",
				"# $orig",
				"extends 'LimerickPowered::Conf';"
			];
		});

		if ($pret && $patcher->save()) {
			cexp "*", "$app_dir/lib/$app_name/Conf.pm";
		}
	} else {
		open(SRC, ">", "$app_dir/lib/$app_name/Conf.pm");
		print SRC join("\n", 
			"package $app_name\:\:Conf;",
			"use strict;",
			"use Poet\:\:Moose;",
			"",
			"extends 'LimerickPowered::Conf';",
			"",
			"1;"
		);
		close(SRC);

		`chown $app_user:$app_grp $app_dir/lib/$app_name/Conf.pm`;

		cnotify "$app_dir/lib/$app_name/Conf.pm";
	}

	if (-f "$app_dir/lib/$app_name/Server.pm") {
		my $patcher = new Limerick::SourcePatcher( "$app_dir/lib/$app_name/Server.pm" );
		my $pret = $patcher->match_line("extends\\s+['\"]Poet\:\:Server['\"]\\s*;", sub {
			my $orig = shift @_;
			return undef if $orig =~ m/^\s*\#/;
			return [
				"# Limerick altered your base library",
				"# $orig",
				"extends 'LimerickPowered::Server';"
			];
		});

		if ($pret && $patcher->save()) {
			cexp "*", "$app_dir/lib/$app_name/Server.pm";
		}
	} else {
		open(SRC, ">", "$app_dir/lib/$app_name/Server.pm");
		print SRC join("\n", 
			"package $app_name\:\:Server;",
			"use strict;",
			"use Poet\:\:Moose;",
			"",
			"extends 'LimerickPowered::Server';",
			"",
			"1;"
		);
		close(SRC);

		`chown $app_user:$app_grp $app_dir/lib/$app_name/Server.pm`;

		cnotify "$app_dir/lib/$app_name/Server.pm";		
	}

	if (-f "$app_dir/lib/$app_name/Import.pm") {
		my $patcher = new Limerick::SourcePatcher( "$app_dir/lib/$app_name/Import.pm" );
		my $pret = $patcher->match_line("extends\\s+['\"]Poet\:\:Import['\"]\\s*;", sub {
			my $orig = shift @_;
			return undef if $orig =~ m/^\s*\#/;
			return [
				"# Limerick altered your base library",
				"# $orig",
				"extends 'LimerickPowered::Import';"
			];
		});

		if ($pret && $patcher->save()) {
			cexp "*", "$app_dir/lib/$app_name/Import.pm";
		}
	} else {
		open(SRC, ">", "$app_dir/lib/$app_name/Import.pm");
		print SRC join("\n", 
			"package $app_name\:\:Import;",
			"use strict;",
			"use Poet\:\:Moose;",
			"",
			"extends 'LimerickPowered::Import';",
			"",
			"1;"
		);
		close(SRC);

		`chown $app_user:$app_grp $app_dir/lib/$app_name/Import.pm`;

		cnotify "$app_dir/lib/$app_name/Import.pm";		
	}

	if (-f "$app_dir/lib/$app_name/DBHandle.pm") {
		# Skip it...
	} else {
		my $patcher = new Limerick::SourcePatcher( { 'source' => "$FindBin::Bin/skel/AppDBHandle.pm-dist", 'safe' => 1 } );
		if (! $patcher->loaded()) {
			cwarn "Cannot open AppDBHandle.pm-dist skel file!";
			return undef;
		}

		my $pret = $patcher->match_line('\s*package\s+', sub {
			return "package $app_name\:\:DBHandle;";
		});

		my $dest = "$app_dir/lib/$app_name/DBHandle.pm";

		if ($pret && $patcher->save($dest)) {
			cnotify $dest;	
			`chown $app_user:$app_grp $dest`;
		} else {
			cwarn "$dest";
			return undef;
		}		
	}

	`touch $app_dir/.limerick-powered`;

	if ($self->{'root'}) {
		`chown $app_user:$app_grp $app_dir/.limerick-powered`;
	}

	return 1;
}

sub i_am_root {
	return whoami() eq 'root' ? 1 : 0;
}

sub whoami {
	return scalar getpwuid($<);
}

sub get_uid_gid {
	my $self = ref $_[0] ? shift @_ : {};
	my $un   = int @_ ? shift @_ : undef;
	chomp($un ||= whoami());

	my @pw = getpwnam($un);
	return [ $pw[2], $pw[3] ];
}

sub get_app_user {
	return scalar getpwuid( get_app_uid(@_) );
}

sub get_app_group {
	return scalar getgrgid( get_app_gid(@_) );
}

sub get_app_uid {
	my $self = ref $_[0] ? shift @_ : {};
	my $app_path = shift @_;

	my @st = stat(File::Spec->catfile($app_path, '.poet_root'));
	if (! int @st) { return undef; }

	my $uid = $st[4];
	return $uid;
}

sub get_app_gid {
	my $self = ref $_[0] ? shift @_ : {};
	my $app_path = shift @_;

	my @st = stat(File::Spec->catfile($app_path, '.poet_root'));
	if (! int @st) { return undef; }

	my $gid = $st[5];
	return $gid;	
}


1;