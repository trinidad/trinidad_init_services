# Trinidad Init Services

Init services based on Apache [Commons Daemon](http://commons.apache.org/daemon/)
and [jruby-jsvc](https://github.com/nicobrevin/jruby-jsvc).

Allows you to run Trinidad as an OS daemon, works on Unix and Windows systems.

## Installation

    $ gem install trinidad_init_services

When the gem is installed the you launch the installation process :

    $ jruby -S trinidad_init_service

This installer guides you through the configuration process and generates a
init.d script if you are on a Unix system or creates the service if you are
on a Windows box.

You can optionally provide a YAML configuration file with defaults specified
for the `trinidad_init_service` command. An example configuration file :

```yaml
app_path: "/home/trinidad/myapp/current"
#ruby_compat_version: RUBY1_9
#service_id: Trinidad # on Windows (defaults to :trinidad_name)
#service_desc: Trinidad Service Description # on Windows (optional)
jruby_home: /opt/jruby
java_home: /opt/java
output_path: /etc/init.d
pid_file: /home/trinidad/myapp/shared/pids/trinidad.pid
out_file: /home/trinidad/myapp/shared/log/trinidad.out # std out/err
jsvc_path: /usr/bin/jsvc # only used on Unix systems
trinidad_opts: "-e production --threadsafe"
java_opts: "-server -Xss1248k -XX:CompileThreshold=8000"
configure_memory: true # asks you for memory requirements (merges java_opts)
#total_memory: 720 # total dedicated in mega-bytes (assumes configure_memory)
#hot_deployment: true # whether using hot-deploys (assumes configure_memory)
```

You can then run the installer like so:

    $ trinidad_init_service --defaults trinidad_init_defaults.yml

If any of the required options are not provided in the configuration file, then
the installer will prompt you for them. If you're running this as part of an
environment initialization script than use the *--know* option or provide
only the defaults file path on the command line (make sure all required options
are there) :

    $ jruby -S trinidad_init_service --know trinidad_init_defaults.yml


**NOTE:** Do not confuse the *defaults.yml* "configuration" file with Trinidad's
own configuration (*config/trinidad.yml*) file used when setting up the server !


### Linux

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

It is not recommended that you mix the `-user` flag with the `run_user` option !

#### Uninstall

manage as every other service (e.g. `update-rc.d -f trinidad defaults` on Ubuntu)
you can even uninstall (will attempt to delete the script as well) using :

    $ [sudo] trinidad_init_service --uninstall /etc/init.d/trinidad


### Windows

#### Execution

Open the **Services** panel under **Administrative Tools** and look for a service
called **Trinidad** (or whatever name you have chosen) then *Start* it.

By default the service is not setup to auto start during boot, that can be changed
from the command-line or using  the Windows Services application.

#### Uninstall

on Windows uninstallation requires to pass the service name (if not default) :

    $ jruby -S trinidad_init_service --uninstall Trinidad

Please note that when the service gets uninstalled (on Windows) usually a restart
is needed for it to be installable again.

## Copyright

Copyright (c) 2012-2014 [Team Trinidad](https://github.com/trinidad).
See LICENSE (http://en.wikipedia.org/wiki/MIT_License) for details.
