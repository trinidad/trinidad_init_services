# Trinidad Init Services

Init services based on Apache [Commons Daemon](http://commons.apache.org/daemon/)
and [jruby-jsvc](https://github.com/nicobrevin/jruby-jsvc).
Allows you to run Trinidad as an OS daemon, works on Unix and Windows systems.

## Installation

    $ jruby -S gem install trinidad_init_services

When the gem is installed the user must launch the installation process:

    $ jruby -S trinidad_init_service

This installer guides you through the configuration process and generates a
init.d script if you are on a Unix system or creates the service if you are
on a Windows box.

You can optionally provide a YAML configuration file with defaults specified 
for the `trinidad_init_service` command. An example configuration file :

    app_path: "/home/trinidad/myapp/current"
    ruby_compat_version: RUBY1_9
    jruby_home: "/opt/jruby"
    java_home: "/opt/java"
    output_path: "/etc/init.d"
    pid_file: "/home/trinidad/myapp/shared/pids/trinidad.pid"
    log_file: "/home/trinidad/myapp/shared/log/trinidad.log"
    jsvc_path: "/usr/bin/jsvc"
    trinidad_options: "-e production"
    trinidad_name: Trinidad
    trinidad_service_id: Trinidad # on Windows (defaults to :trinidad_name)
    trinidad_service_desc: Trinidad Service Description # on Windows (optional)

You can then run the installer like so:

    $ trinidad_init_service --defaults trinidad_init_defaults.yml

If any of the required options are not provided in the configuration file, then 
the installer will prompt you for them. If you're running this as part of an 
environment initialization script than use the *--no-ask* option or provide 
only the defaults file path on the command line (make sure all required options
are there) :

    $ jruby -S trinidad_init_service trinidad_init_defaults.yml


**NOTE:** Do not confuse the *defaults.yml* "configuration" file with Trinidad's
own configuration (*config/trinidad.yml*) file used when setting up the server !


### Unix

#### Requirements

To run Trinidad as a daemon [jsvc](http://commons.apache.org/daemon/jsvc.html) is
used. Some distributions provide binary packages of JSVC but not all, for these
we do bundle JSVC's sources and try to compile the binary during configuration for
you. However please note that to build JSVC on Unix you will need :

* an ANSI-C compliant compiler (GCC is good) and GNU Make
* Java SDK installed (a JRE installation is not enough)

#### Execution

When the installation process finishes you can use the script generated to launch 
the server as a daemon with the options start|stop|restart, i.e:

    $ /etc/init.d/trinidad restart

#### Running as a Non-Root User

By default, the Trinidad server process will run as the same user that ran the 
`/etc/init.d/trinidad start` command. But the service can be configured to run 
as a different user. The preferred method for doing this is the `run_user:` 
attribute in the configuration YAML (or it's corresponding value at the prompt).  
For example:

    app_path: "/home/trinidad/myapp/current"
    # ...
    run_user: trinidad
    # ...

This causes the the server to run with non-root privileges (it essentially executes 
as `sudo -u run_user jsvc ...`).

On some platforms, however, it may be required that you use the JSVC `-user` argument.
This can be configured with the `JSVC_ARGS_EXTRA` environment variable, like this:

    JSVC_ARGS_EXTRA="-user myuser" /etc/init.d/trinidad start

It not recommended that you mix the `-user` flag with the `run_user` option !


### Windows

#### Execution

Open the **Services** panel under **Administrative Tools** and look for a service 
called **Trinidad**.


## Copyright

Copyright (c) 2011-2012 David Calavera<calavera@apache.org>. See LICENSE for details.
