require 'java'
require 'jruby'
require 'fileutils'
require 'rbconfig'
require 'shellwords'

module Trinidad
  module InitServices
    class Configuration

      def self.windows?
        RbConfig::CONFIG['host_os'] =~ /mswin|mingw/i
      end

      def self.macosx?
        RbConfig::CONFIG['host_os'] =~ /darwin/i
      end

      def initialize(stdin = STDIN, stdout = STDOUT)
        @stdin, @stdout = stdin, stdout
      end

      SERVICE_DESC = 'JRuby on Rails/Rack server'

      def configure(defaults = {})
        if ( @app_path = defaults["app_path"] ).nil?
          unless @base_path = defaults["base_path"]
            @app_path = ask_path('Application (base - in case of multiple apps) path', false) do
              raise "application/base path not provided (try . if current directory is the app)"
            end
          end
        end

        options_ask = 'Trinidad options?'

        @service_id = defaults['service_id'] || defaults['trinidad_service_id']
        @service_name = defaults['service_name'] || defaults['trinidad_name']
        @service_desc = defaults['service_desc'] || defaults['trinidad_service_desc']

        if windows?
          options_ask << ' (separated by `;`)'

          @service_id ||= ask('Service ID? {alphanumeric and underscores only}', default_service_id)
          name_default = @service_id.gsub('_', ' ')
          @service_name ||= ask('Service (display) name? {alphanumeric and spaces only}', name_default)
          @service_desc ||= ask('Service description? {alphanumeric and spaces only}', SERVICE_DESC)
        else
          @service_id ||= default_service_id
          @service_name ||= @service_id
          @service_desc ||= SERVICE_DESC
        end

        @trinidad_opts = defaults["trinidad_options"] || defaults["trinidad_opts"]

        if @trinidad_opts.is_a?(String) # leave 'em as are
          if @app_path && ! @trinidad_opts.index('-d') && ! @trinidad_opts.index('--dir')
            @trinidad_opts = "--dir #{@app_path} #{@trinidad_opts}"
          end
        elsif @trinidad_opts
          if @app_path && ! @trinidad_opts.find { |opt| opt.index('-d') || opt.index('--dir') }
            @trinidad_opts.unshift("--dir #{@app_path}")
          end
        else
          @trinidad_opts = [ ask(options_ask, '-e production') ]
        end

        if @trinidad_opts.is_a?(Array)
          @trinidad_opts.map! { |opt| Shellwords.shellsplit(opt) }
          @trinidad_opts.flatten! # split: 'opt' -> [ 'opt' ]
        end

        @jruby_home = defaults['jruby_home'] || ask_path('JRuby home', default_jruby_home)
        @ruby_compat_version = defaults["ruby_compat_version"] || default_ruby_compat_version
        @jruby_opts = configure_jruby_opts(@jruby_home, @ruby_compat_version)
        initialize_paths(@jruby_home)

        @java_home = defaults['java_home'] || ask_path('Java home', default_java_home)

        @java_opts = defaults['java_opts'] || []
        @java_opts = @java_opts.strip if @java_opts.is_a?(String)

        # can be disabled with *configure_memory: false*
        configure_memory_requirements(defaults, @java_home)

        message = windows? ?
          configure_windows_service(defaults, @java_home) :
            configure_unix_daemon(defaults, @java_home)
        say message if message.is_a?(String)
      end

      MEMORY_DEFAULT = 720

      def configure_memory_requirements(defaults, java_home)
        return if defaults.key?('configure_memory') && ! defaults['configure_memory']

        if defaults['configure_memory'] || ask('Configure JVM memory (JAVA_OPTS)? y/n', 'n') == 'y'

          total_memory = defaults['total_memory'] ||
            ask('Total (max) memory dedicated to Trinidad? (in MB)', MEMORY_DEFAULT)
          total_memory = total_memory.to_i
          if total_memory <= 0
            warn "changing total_memory to '#{MEMORY_DEFAULT}' default (provided value <= 0)"
            total_memory = MEMORY_DEFAULT
          end
          if total_memory <= 160
            warn "provided total_memory '#{total_memory}' seems low (server migh not start)"
          end

          if current_java_home?(java_home) && current_java_vendor_sun_or_oracle?
            # 720 total memory: (Max) 144M PermGen, 72M CodeCache, 504M Heap

            add_java_opt('-XX:+UseCodeCacheFlushing')
            cache_size = total_memory >= 800 ? 80 : ( total_memory / 10 )
            cache_size = 100 if total_memory >= 2000
            cache_size = 120 if total_memory >= 3000
            cache_size = 140 if total_memory >= 4000
            add_java_opt('-XX:ReservedCodeCacheSize=', "#{cache_size}m")

            heap_size = total_memory - cache_size

            if ! defaults.key?('hot_deployment') || ! defaults['hot_deployment']
              hot_deploy = ask('Support hot (re-)deployment? y/n', 'n') == 'y'
            else
              hot_deploy = true
            end

            if hot_deploy && current_java_version_6?
              # on Java 7 G1 sweeps PermGen on full GC
              add_java_opt('-XX:+UseConcMarkSweepGC') if hot_deploy
              add_java_opt('-XX:+CMSClassUnloadingEnabled') if hot_deploy
            end

            if current_java_version_at_least_8?
              # probably a good idea to limit meta-space size :
              meta_size = heap_size / 5 # 20% (unlimited by default)
              meta_size = min(heap_size / 4, meta_size + 100) if hot_deploy

              unless defaults['total_memory'] # do not ask if configured
                meta = ask('Confirm meta-space size limit: (-XX:MaxMetaspaceSize in MB)', meta_size)
                meta_size = parse_memory_setting(meta, meta_size)
              end

              add_java_opt('-XX:MaxMetaspaceSize=', "#{meta_size}m") if meta_size
              heap_size -= meta_size.to_i
            else
              perm_size = heap_size / 5 # 20%
              perm_size = min(heap_size / 4, perm_size + 100) if hot_deploy

              unless defaults['total_memory'] # do not ask if configured
                perm = ask('Confirm perm-gen size limit: (-XX:MaxPermSize in MB)', perm_size)
                perm_size = parse_memory_setting(perm, perm_size)
              end

              add_java_opt('-XX:MaxPermSize=', "#{perm_size}m") if perm_size
              heap_size -= perm_size.to_i
            end

            heap_size = ( heap_size / 10 ) * 10
            add_java_opt('-Xmx', "#{heap_size}m")
            min_heap_size = min(heap_size / 2, 500)
            add_java_opt('-Xms', "#{min_heap_size}m")

          else # only try to limit heap (vendors such as IBM support it) :

            heap_size = total_memory - ( total_memory / 15 ) # just a guess

            heap_size = ( heap_size / 10 ) * 10
            add_java_opt('-Xmx', "#{heap_size}m")

          end

          add_java_opt('-XX:+UseCompressedOops') if current_java_version_6? && os_arch =~ /64/

        end
      end

      def add_java_opt(java_opt, opt_suffix = nil)
        if @java_opts.is_a?(String)
          return false if @java_opts.index(java_opt)
          @java_opts << ( windows? ? ';' : ' ' ) unless @java_opts.strip.empty?
        else
          return false if @java_opts.find { |opt| opt.index(java_opt) }
        end
        @java_opts << "#{java_opt}#{opt_suffix}"
      end

      def configure_jruby_opts(jruby_home = @jruby_home, ruby_compat_version = @ruby_compat_version)
        opts = []
        opts << "-Djruby.home=#{jruby_home}"
        opts << "-Djruby.lib=#{File.join(jruby_home, 'lib')}"
        opts << "-Djruby.script=jruby"
        opts << "-Djruby.daemon.module.name=Trinidad"
        opts << "-Djruby.compat.version=#{ruby_compat_version}"
        opts
      end

      def initialize_paths(jruby_home = default_jruby_home)
        @trinidad_daemon_path = File.expand_path('../../trinidad/daemon.rb', __FILE__)
        @jars_path = File.expand_path('../../../trinidad-libs', __FILE__)

        @classpath = ['jruby-jsvc.jar', 'commons-daemon.jar'].map { |jar| File.join(@jars_path, jar) }
        @classpath << File.join(jruby_home, 'lib', 'jruby.jar')
      end

      def configure_unix_daemon(defaults, java_home = default_java_home)
        unless @jsvc = defaults["jsvc_path"] || detect_jsvc_path
          @jsvc = ask_path("path to jsvc binary (leave blank and we'll try to compile)", '')
          if @jsvc.empty? # unpack and compile :
            jsvc_unpack_dir = defaults["jsvc_unpack_dir"] || ask_path("dir where jsvc dist should be unpacked", '/usr/local/src')
            @jsvc = compile_jsvc(jsvc_unpack_dir, java_home)
            say "jsvc binary available at: #{@jsvc} " +
                 "(consider adding it to $PATH if you plan to re-run trinidad_init_service)"
          end
        end

        @pid_file = defaults['pid_file'] || ask_path('pid file', '/var/run/trinidad/trinidad.pid')
        @out_file = defaults['out_file'] || defaults['log_file'] ||
          ask_path('out file (where system out/err gets redirected)', '/var/log/trinidad/trinidad.out')

        @pid_file = File.join(@pid_file, 'trinidad.pid') if File.exist?(@pid_file) && File.directory?(@pid_file)
        make_path_dir(@pid_file, "could not create dir for '#{@pid_file}', make sure dir exists before running daemon")
        @out_file = File.join(@out_file, 'trinidad.out') if File.exist?(@out_file) && File.directory?(@out_file)
        make_path_dir(@out_file, "could not create dir for '#{@out_file}', make sure dir exists before running daemon")

        @run_user = defaults['run_user'] || ask('run daemon as user (enter a non-root username or leave blank)', '')
        if ! @run_user.empty? && `id -u #{@run_user}` == ''
          raise ArgumentError, "user '#{@run_user}' does not exist (leave blank if you're planning to `useradd' later)"
        end

        @output_path = defaults['output_path'] || ask_path('init.d output path', '/etc/init.d')

        require('erb'); daemon = ERB.new(
          File.read(
            File.expand_path('../../init.d/trinidad.erb', File.dirname(__FILE__))
          ), nil, '-' # safe_level=nil, trim_mode=nil
        ).result(binding)

        service_file = File.join(@output_path, @service_id ||= 'trinidad')
        begin
          File.open(service_file, 'w') { |file| file.write(daemon) }
        rescue Errno::EACCES => e
          begin
            service_file = File.basename(service_file) # leave in current WD
            service_file = File.expand_path(service_file)
            File.open(service_file, 'w') { |file| file.write(daemon) }
            warn "#{e.message} left init.d script at #{service_file}"
          rescue
            raise e
          end
        end
        FileUtils.chmod @run_user.empty? ? 0744 : 0755, service_file

        if chkconfig?
          command = "chkconfig #{@service_id} on"
        else
          command = "update-rc.d -f #{@service_id} remove"
        end
        if service_file.start_with?('/etc')
          unless exec_system(command, :allow_failure)
            warn "\nNOTE: run `#{command}` as a super-used to enable service"
          end
        else
          warn "\nNOTE: run `cp #{service_file} /etc/init.d` and `#{command}` as a super-used to enable service"
        end
      end

      def configure_windows_service(defaults, java_home = default_java_home)
        srv_path = detect_prunsrv_path

        classpath = escape_windows_options(@classpath)
        trinidad_options = escape_windows_options(@trinidad_opts, :split)

        jvm_options = escape_windows_options(@jruby_opts)
        unless @java_opts.empty?
          jvm_options << ';' << escape_windows_options(@java_opts)
        end

        log_path = defaults['log_path'] || "%SystemRoot%\\System32\\LogFiles\\#{@service_id}"
        @out_file = defaults['out_file'] || defaults['log_file'] ||
          ask_path('out file (where system out/err gets redirected), leave blank for prunsrv default', '')
        @pid_file = defaults['pid_file'] || "#{@service_id}.pid"

        #stop_timeout = defaults['stop_timeout'] || 5

        # //TS  Run the service as a console application
        #       This is the default operation (if no option is provided).
        # //RS  Run the service 	Called only from ServiceManager
        # //ES  Start (execute) the service
        # //SS  Stop the service
        # //US  Update service parameters
        # //IS  Install service
        # //DS  Delete service 	Stops the service first if it is currently running
        # //PP[//seconds]  Pause 	Default is 60 seconds

        if service_listed_windows?(@service_id)
          say "service '#{@service_id}' already installed, will update instead of install"
          command = %Q{//US//#{@service_id} --DisplayName="#{@service_name}"}
        else
          command = %Q{//IS//#{@service_id} --DisplayName="#{@service_name}"}
        end

        command << " --Description=\"#{@service_desc}\""
        command << " --Install=#{srv_path} --Jvm=auto"
        command << " --JavaHome=\"#{escape_windows_path(java_home)}\""
        command << " --StartMode=jvm --StopMode=jvm"
        command << " --StartClass=com.msp.procrun.JRubyService --StartMethod=start"
        command << " --StartParams=\"#{escape_windows_path(@trinidad_daemon_path)};#{trinidad_options}\""
        command << " --StopClass=com.msp.procrun.JRubyService --StopMethod=stop"
        command << " --Classpath=\"#{classpath}\""
        command << " ++JvmOptions=\"#{jvm_options}\""
        command << " --LogPath=\"#{escape_windows_path(log_path)}\""
        command << " --PidFile=#{@pid_file}" # always assumed log_path relative

        if @out_file && ! @out_file.empty?
          out_file = escape_windows_path(@out_file)
          command << " --StdOutput=\"#{out_file}\" --StdError=\"#{out_file}\""
        else
          command << " --StdOutput=auto --StdError=auto"
        end

        exec_system "#{srv_path} #{command}"

        warn "\nNOTE: service needs to be started manually, to start during boot run:\n" <<
          "#{srv_path} //US//#{@service_id} --Startup=auto"

        "\nHINT: you may use prunsrv to manage your service, try running:\n#{srv_path} help"
      end

      def uninstall(service = nil)
        initialize_paths
        service ||= default_service_id
        windows? ? uninstall_windows_service(service) : uninstall_unix_daemon(service)
      end

      def uninstall_windows_service(service)
        srv_path = detect_prunsrv_path
        exec_system "#{srv_path} //DS//#{service}" # does stop first if needed
      end

      def service_listed_windows?(service)
        # *sc* will allow SERVICE_NAME only (DISPLAY_NAME won't work)
        out = `sc queryex type= service state= all | find "#{service}"`
        return false if out.chomp.empty?
        # "SERVICE_NAME: Trinidad\nDISPLAY_NAME: Trinidad\n"
        !! ( out =~ /SERVICE_NAME: #{service}$/i )
      end

      def uninstall_unix_daemon(service)
        unless File.exist?(service)
          service = File.expand_path(service, '/etc/init.d')
        end
        name = File.basename(service) # e.g. /etc/init.d/trinidad

        unless service_listed_unix?(service)
          warn "service '#{service}' seems to be NOT installed/configured"
        end

        if chkconfig?
          exec_system command = "chkconfig #{name} stop", :allow_failure
          exec_system command = "chkconfig #{name} off"
        else # assuming Debian based
          exec_system command = "service #{name} stop", :allow_failure
          exec_system command = "update-rc.d -f #{name} remove"
        end
      rescue => e
        say "uninstall failed, maybe try running `#{command}` as super-user"
        raise e
      else
        FileUtils.rm(service) if File.exist?(service)
      end

      def service_listed_unix?(service)
        if chkconfig?
          ! `chkconfig --list | grep #{service}`.chomp.empty?
        else
          ! `service --status-all | grep #{service}`.chomp.empty?
        end
      end

      private

      def exec_system(command, allow_failure = nil)
        log_command command
        ok = system command
        unless allow_failure
          raise "could not execute `#{command}`" if ok.nil?
          raise "`#{command}` failed" unless ok
        end
        ok
      end

      def log_command(command)
        say command
        log && (log.puts "#{command}\n\n"; log.flush)
      end

      def log
        return @_log || nil if defined?(@_log) && ! @_log.nil?
        ( @_log = File.open('trinidad_init_service.log', 'w') rescue false ) || nil
      end

      def log?; defined?(@_log) ? !! @_log : nil end

      def escape_windows_path(path)
        path.gsub(%r{/}, '\\')
      end

      def escape_windows_options(options, split = nil)
        if options.is_a?(String)
          return escape_windows_path(options) unless split
          options = options.split(' ')
        end
        options.map { |opt| escape_windows_path(opt) }.join(';')
      end

      def min(num1, num2); num1 <= num2 ? num1 : num2 end

      def empty?(arg)
        return true unless arg
        ! arg.respond_to?(:empty) || arg.empty?
      end

      def parse_memory_setting(memory, default = nil)
        return default if empty?(memory)
        return false if memory == 'n'
        return default if memory == 'y'
        memory = memory[0...-1] if memory.is_a?(String) && memory =~ /m$/i
        memory
      end

      def chkconfig? # available in RH based distributions
        return @chkconfig unless (@chkconfig ||= nil).nil?
        @chkconfig = ! `which chkconfig`.chomp.empty?
      end

      def default_service_id; windows? ? 'Trinidad' : 'trinidad' end

      def default_jruby_home; current_jruby_home end

      def current_jruby_home
        Java::JavaLang::System.get_property("jruby.home")
      end

      def default_java_home
        ENV['JAVA_HOME'] || current_java_home
      end

      def current_java_home
        ENV_JAVA['java.home']
      end

      def current_java_home?(java_home)
        java_home == current_java_home || begin
          real_java_home = java.io.File.new(java_home).canonical_path
          real_java_home == current_java_home || "#{real_java_home}/jre" == current_java_home
        end
      end

      def current_java_vendor_sun_or_oracle?
        ENV_JAVA['java.vendor'] =~ /^(Oracle|Sun)/
      end

      def current_java_version(split = nil)
        version = ENV_JAVA['java.version']
        return version unless split
        @current_java_version ||= begin
          # e.g. "1.7.0_51" -> [ 1, 7, 0 ]
          # but  "1.8.0"    -> [ 1, 8, 0 ]
          if i = version.index('_')
            version = version[0, i]
          end
          version.split('.').map(&:to_i)
        end
      end

      def current_java_version_6?
        current_java_version(true)[1] == 6
      end

      def current_java_version_7?
        current_java_version(true)[1] == 7
      end

      def current_java_version_at_least_8?
        current_java_version(true)[1] >= 8
      end

      def default_ruby_compat_version; current_ruby_compat_version end

      def current_ruby_compat_version
        # deprecated on 9k but still working (returns RUBY2_1)
        JRuby.runtime.getInstanceConfig.getCompatVersion.to_s
      end

      def windows?
        self.class.windows?
      end

      def macosx?
        self.class.macosx?
      end

      def bundled_jsvc_path # only called on *nix
        jsvc = 'jsvc_' + (macosx? ? 'darwin' : 'linux')
        jsvc_path = File.join(@jars_path, jsvc)
        # linux version is no longer bundled - as long as it is not present jsvc
        # will be compiled from src (if not installed already #detect_jsvc_path)
        File.exist?(jsvc_path) ? jsvc_path : nil
      end

      def detect_jsvc_path # only called on *nix
        jsvc_path = `which jsvc` # "/usr/bin/jsvc\n"
        jsvc_path.chomp!
        jsvc_path.empty? ? bundled_jsvc_path : jsvc_path
      end

      def compile_jsvc(jsvc_unpack_dir, java_home = default_java_home)
        unless File.exist?(jsvc_unpack_dir)
          begin
            FileUtils.mkdir(jsvc_unpack_dir)
          rescue
            raise "specified path does not exist: #{jsvc_unpack_dir.inspect}"
          end
        end
        unless File.directory?(jsvc_unpack_dir)
          raise "specified path: #{jsvc_unpack_dir.inspect} is not a directory"
        end
        unless File.writable?(jsvc_unpack_dir)
          raise "specified path: #{jsvc_unpack_dir.inspect} is not writable"
        end

        jsvc_unix_src = File.expand_path('../../jsvc-unix-src', File.dirname(__FILE__))
        FileUtils.cp_r(jsvc_unix_src, jsvc_unpack_dir)

        jsvc_dir = File.expand_path('jsvc-unix-src', jsvc_unpack_dir)
        File.chmod(0755, File.join(jsvc_dir, "configure"))
        # ./configure
        unless jdk_home = detect_jdk_home(java_home)
          warn "seems you only have a JRE installed, a JDK is needed to compile jsvc"
          jdk_home = java_home # it's still worth trying
        end
        command = "cd #{jsvc_dir} && ./configure --with-java=#{jdk_home}"
        say "configuring jsvc ..."
        command_output = `#{command}`
        if $?.exitstatus != 0
          say command_output
          raise "`#{command}` failed with status: #{$?.exitstatus}"
        end

        # make
        command = "cd #{jsvc_dir} && make"
        say "compiling jsvc ..."
        command_output = `#{command}`
        if $?.exitstatus != 0
          say command_output
          raise "`#{command}` failed with status: #{$?.exitstatus}"
        end

        File.expand_path('jsvc', jsvc_dir) # return path to compiled jsvc binary
      end

      def detect_jdk_home(java_home = default_java_home)
        # JDK has an include directory with headers :
        if File.directory?(File.join(java_home, 'include'))
          return java_home
        end
        # java_home might be a nested JDK path e.g. /opt/java/jdk/jre
        jdk_home = File.dirname(java_home) # /opt/jdk/jre -> /opt/jdk
        if File.exist?(File.join(jdk_home, 'bin/java'))
          return jdk_home
        end
        nil
      end

      def detect_prunsrv_path # only called on windows
        prunsrv_path = `for %i in (prunsrv.exe) do @echo.%~$PATH:i` rescue ''
        # a kind of `which prunsrv.exe` (if not found returns "\n")
        prunsrv_path.chomp!
        prunsrv_path.empty? ? bundled_prunsrv_path : prunsrv_path
      end

      def bundled_prunsrv_path(arch = os_arch)
        # "amd64", "i386", "x86", "x86_64"
        path = 'windows'
        if arch =~ /amd64/i # amd64
          path << '/amd64'
        elsif arch =~ /64/i # x86_64
          path << '/ia64'
        # else "i386", "x86"
        end
        File.join(@jars_path, path, 'prunsrv.exe')
      end

      def os_arch
        ENV_JAVA['os.arch']
      end

      def make_path_dir(path, error = nil)
        dir = File.dirname(path)
        return if File.exist?(dir)
        begin
          FileUtils.mkdir_p dir, :mode => 0775
        rescue Errno::EACCES => e
          raise unless error
          say "#{error} (#{e})"
        end
      end

      public

      def ask_path(question, default = nil)
        unless path = ask(question, default) # nil, false
          return path if path.nil?
          block_given? ? yield : raise("#{question.inspect} not provided!")
        end
        path.empty? ? path : File.expand_path(path)
      end

      def ask(question, default = nil)
        return default if ! @stdin.tty? || ! ask?

        question = "#{question}?" if ! question.index('?') || ! question.index(':')
        question += " [#{default}]" if default &&
          ( ! default.is_a?(String) || ! default.empty? )

        result = nil
        while result.nil?
          @stdout.print("#{question}  ")
          @stdout.flush

          result = @stdin.gets

          if result
            result.chomp!
            result = default if result.size == 0
          end
        end
        result
      end

      def ask?
        @ask = true unless defined? @ask; return @ask
      end

      def ask=(flag); @ask = !!flag end
      public :ask=

      def say(msg)
        puts msg if say?
      end

      def say?
        @say = true unless defined? @say; return @say
      end

      def say=(flag); @say = !!flag end
      public :say=

    end
  end
end
