== 1.3.0 (pend-ii-ng)

* fix uninstall failing (alwo try supporting RH standarts)
* revised service id/name/desc configuration (to be 'more' similar on platforms)
* improved java_home detection and error message
* align with boot tag script conventions  - avoid insserv: warning (#31)
* support for some detecting of JAVA_OPTS and calculating JVM memory requirements
* allow to detect 2.x ruby compat mode (JRuby >= 1.7)
* better init.d compat with other/older shells + support customizing JAVA_OPTS
* refactor init.d script - make sure -cwd $BASE_DIR happens + warn on missing base
* do not ask for ruby compat version - simply use the current one
* refactor log_file to out_file ... as it might be confusing
* decrease default stack-size 1536k should be still a very 'pessimistic' guess
* allow to configure jsvc's -wait and -keepstdin in generated init.d script
* better compatibility for upcoming Trinidad 1.5
* update commons-daemon to 1.0.15

== 1.2.3 (2013-09-10)

* detect if the process is still actually running
  to handle starting the service after the machine was halted and restarted (#36)
* update to jruby-jsvc 0.5.1
* update to commons-daemon 1.0.13
* a better running PID ps check (fix `ps -p` without grep)

== 1.2.2 (2012-10-23)

* remove JRUBY_OPTS from init.d script (#28)
* latest jruby binary compatibility
  - JAVA_MEM accepted in (and converted to) -Xmx format
  - JAVA_STACK accepted in (and converted to) -Xss format
  - added JAVA_MEM_MIN (-Xms format)

== 1.2.1 (2012-09-06)

* publicize ask= and say= (used from trinidad_init_service) (#25)

== 1.2.0 (2012-09-03)

* add an --uninstall option (requested on Windows) (#22)
* make ruby binary behave like a "gemtleman" see `trinidad_init_service --help`
* added possibility to specify service id and service description under windows
* ensure $PIDFILE_DIR exists and $RUN_USER has access

== 1.1.6 (2012-05-18)

* fix windows option formatting with prunsrv's arguments
* detect prunsrv.exe on windows PATH

== 1.1.5 (2012-03-06)

* not working arch detection on Windows + missing 32-bit prunsrv.exe

== 1.1.4 (2012-03-01)

* JSVC sources packaged along the gem and compiled on demand (#6)
* improve JRuby's native path detection in generated init.d script
* make gem usable with bundler :git => paths

== 1.1.3 (2012-02-20)

* do not ask for a path with $RUN_USER

== 1.1.2 (2012-01-17)

* revert previous -errfile fix
* use a better procfile name (#10)

== 1.1.1 (2012-01-16)

* issue on with -errfile &1 being misinterpreted (#8)

== 1.1.0 (2012-01-04)

* fix bug that didn't allow to create several services with different ids.
* allow to provide a configuration file to load the options from.

== 1.1.0.pre (2011-09-30)

* load prunsrv on Windows according with the architecture

== 1.0.0 (2011-06-11)

* rebranded gem
* fix shutdown compatibility errors with Trinidad 1.2.2 and above

== 0.4.2 (2011-05-17)

* fix several minor bugs

== 0.4.1 (2011-01-18)

* ensure the unix script is executable by default

== 0.4.0 (2011-01-13)

* generate Windows service.

== 0.3.2

* remove profile.jar from init script since it's no more bundled with JRuby

== 0.3.1

* use absolute path for configuration options
* start Trinidad from the application path

== 0.3.0

* remove init script extension

== 0.2.0

* fix several bugs

== 0.1.0

* initial release
