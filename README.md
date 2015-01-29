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

Neat Features
----

Tips and Tricks
----

References
----
Special thanks for Jonathan Schwartz for inspiration, and for creating Mason and Poet on which Limerick is based.