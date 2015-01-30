Limerick -- Quick _Poet_-ry for *nix/OS X
====

by [corey@eviltreehouse.com](mailto:corey@eviltreehouse.com)

Current version: **version 0.5.0** alpha


Abstract
----
_Limerick_ is a suite of libraries and utilities to assist in the creation and management of _Poet_ powered 'Plack' web applications. It provides a central 'app core' tool that makes running many independent Poet apps on a singular server a breeze. It also injects a few helper libraries seamlessly into your existing app architecture to super-charge your application for things like database connectivity. 

Quick Example
----
To begin, install _limerick_ in a directory to act as your 'app core' directory, e.g. `/opt/apps`. Within this directory the main `limerick`  script will reside, as well as its internal library structure and a few other misc directories. Additionally a `build` exists that will house various auto-generated scripts and configuration files that will assist you in managing your web applications.

Once installed, run `poet init` to create your stub configuration file, named `limerick-config.json`. It is standard-compliant JSON, which you are free to edit manually as well as via commands of the `limerick` utility. _Note: since the file is edited by the script on occasion, any non-standard JSON like comments may be lost_. 

If you have an existing site, go ahead and symlink your poet root directory to a local directory within your app core. But for this example, we will create a brand new Poet app:

	$ limerick app-new CoolApp

limerick will launch `poet new ...` to set up your root Poet app, and then automatically run `limerick app-add ...` to add your app for management, as well as inject the helper libraries into your base Poet application. If you had symlinked an existing app, you would instead just run `limerick app-add <dir-name>` to perform the same steps.

Once your application is added into limerick, it exists as a block of JSON code in the configuration file that looks similar to this:

      "coolapp" : {
         "active" : true,
         "approot" : "/opt/apps/coolapp",
         "bind" : "public_ip",
         "description" : "My Cool New Application",
         "hostname" : [
            "coolapp.io",
            "*.coolapp.io"
         ],
         "mode" : "development",
         "server" : "Starlet",
         "user" : false
      }

Within this block are a number of critical and easily tunable configuration elements like:

* Whether your app is active not not
* What 'run mode' your application should be started in.
* The Plack server software to power your app.
* The hostname(s) and IP that will 'listen' for requests to your app through your supported http(s) server (e.g. _nginx_)
* If running in root mode (`root : true`), you can even define which local user to run your application codebase as to ensure permission separation. 
* Which of your net interfaces to 'bind' your application to. Interfaces are managed within the configuration file as well giving you a single place to manage all your network definitions.

Once it is configured per your liking, you can run `limerick build` and it will generate into your `build` directory:

* An RC script that will launch all your applications
* A fronted configuration file that you can include into your fronted  global configuration to ensure your applications are accessible via reverse-proxy.

Limerick will also auto-assign local listen ports for each app within the valid range you specify so you don't need to worry about two separate applications accidentally utilizing each others port numbers.

Neat Features
----

### Database Integration
Limerick provides a Poet "app class" library (as well as some global extensions) that allow you to easily configure your database connections within your existing Poet YAML configuration, and to make that handle available to your application:

	# in development.cfg
	database:
		hostname: localhost
		#socket: /tmp/mysql.sock -- sockets are supported too!
		database: coolapp_dev
		engine: mysql
		username: coolapp
	
	# in your secure.cfg file held elsewhere (optional, but supported)
	database:
		password: C00l4pp^DB!

	# Now in your app ran in 'development' mode, get a database handle manually...
	my $dbh = $poet->app_class('DBHandle')->new();

	# Or, get it via export()
	use Poet qw($poet $conf $dbh);

### Toggling Apps
You can toggle apps off and on from startup by calling `./limerick app-<on|off>` and re-calling `limerick build` to update your configurations.

Tips and Tricks
----

References
----

**Using databases? Need a migration framework?** I have also crafted a database migration framework that works well with limerick/Poet called _Verses_. Check it out: [Verses on github/eviltreehouse](http://github.com/eviltreehouse/db-verses.git).



Special thanks for [Jonathan Swartz](http://search.cpan.org/~jswartz/) for inspiration, and for creating Mason and Poet on which Limerick and a number of eTh tools are based.