require 'erb'
require 'java'
require 'jruby'
require 'fileutils'
require 'rbconfig'
require 'shellwords'

module Trinidad
  module InitServices

    class Configuration
      def initialize(stdin = STDIN, stdout = STDOUT)
        @stdin = stdin
        @stdout = stdout
      end

      def initialize_paths(jruby_home = default_jruby_home)
        @trinidad_daemon_path = File.expand_path('../../trinidad/daemon.rb', __FILE__)
        @jars_path = File.expand_path('../../../trinidad-libs', __FILE__)

        @classpath = ['jruby-jsvc.jar', 'commons-daemon.jar'].map { |jar| File.join(@jars_path, jar) }
        @classpath << File.join(jruby_home, 'lib', 'jruby.jar')
      end

      def configure_jruby_opts
        opts = []
        opts << "-Djruby.home=#{@jruby_home}"
        opts << "-Djruby.lib=#{File.join(@jruby_home, 'lib')}"
        opts << "-Djruby.script=jruby"
        opts << "-Djruby.daemon.module.name=Trinidad"
        opts << "-Djruby.compat.version=#{@ruby_compat_version}"
        opts
      end

      def configure(defaults={})
        @app_path = defaults["app_path"] || ask_path('Application path?')
        @trinidad_options = ["-d #{@app_path}"]
        options_ask = 'Trinidad options?'
        options_default = '-e production'
        collect_windows_opts(options_ask, defaults) if windows?

        @trinidad_options << (defaults["trinidad_options"] || ask(options_ask, options_default))
        @trinidad_options.map! { |opt| Shellwords.shellsplit(opt) }.flatten!
        @jruby_home = defaults["jruby_home"] || ask_path('JRuby home?', default_jruby_home)
        @ruby_compat_version = defaults["ruby_compat_version"] || ask('Ruby 1.8.x or 1.9.x compatibility?', default_ruby_compat_version)
        @jruby_opts = configure_jruby_opts
        initialize_paths(@jruby_home)

        windows? ? configure_windows_service : configure_unix_daemon(defaults)
        puts 'Done.'
      end

      def configure_unix_daemon(defaults)
        @java_home = defaults["java_home"] || ask_path('Java home?', default_java_home)
        unless @jsvc = defaults["jsvc_path"] || detect_jsvc_path
          @jsvc = ask_path("path to jsvc binary (leave blank and we'll try to compile)?", '')
          if @jsvc.empty? # unpack and compile :
            jsvc_unpack_dir = defaults["jsvc_unpack_dir"] || ask_path("dir where jsvc dist should be unpacked?", '/usr/local/src')
            @jsvc = compile_jsvc(jsvc_unpack_dir, @java_home)
            puts "jsvc binary available at: #{@jsvc} " + 
                 "(consider adding it to $PATH if you plan to re-run trinidad_init_service)"
          end
        end
        @output_path = defaults["output_path"] || ask_path('init.d output path?', '/etc/init.d')
        @pid_file = defaults["pid_file"] || ask_path('pid file?', '/var/run/trinidad/trinidad.pid')
        @log_file = defaults["log_file"] || ask_path('log file?', '/var/log/trinidad/trinidad.log')
        @run_user = defaults["run_user"] || ask('run daemon as user (enter a non-root username or leave blank)?', '')
        
        if @run_user != '' && `id -u #{@run_user}` == ''
          raise ArgumentError, "user '#{@run_user}' does not exist (leave blank if you're planning to `useradd' later)"
        end
        
        @pid_file = File.join(@pid_file, 'trinidad.pid') if File.exist?(@pid_file) && File.directory?(@pid_file)
        make_path_dir(@pid_file, "could not create dir for '#{@pid_file}', make sure dir exists before running daemon")
        @log_file = File.join(@log_file, 'trinidad.log') if File.exist?(@log_file) && File.directory?(@log_file)
        make_path_dir(@log_file, "could not create dir for '#{@log_file}', make sure dir exists before running daemon")
        
        daemon = ERB.new(
          File.read(
            File.expand_path('../../init.d/trinidad.erb', File.dirname(__FILE__))
          )
        ).result(binding)

        puts "Moving trinidad to #{@output_path}"
        trinidad_file = File.join(@output_path, "trinidad")
        File.open(trinidad_file, 'w') { |file| file.write(daemon) }
        FileUtils.chmod(@run_user == '' ? 0744 : 0755, trinidad_file)
      end

      def collect_windows_opts(options_ask, defaults)
        options_ask << '(separated by `;`)'
        name_ask = 'Service name? {Alphanumeric and spaces only}'
        name_default = 'Trinidad'
        @trinidad_name = defaults["trinidad_name"] || ask(name_ask, name_default)

        id_ask = 'Service ID? {Alphanumeric and underscores only}'
        id_default = @trinidad_name.gsub(/\s+/, '_').gsub(/\W/, '')
        @trinidad_service_id = defaults["trinidad_service_id"] || ask(id_ask, id_default)

        desc_ask = 'Service description? {Alphanumeric and spaces only}'
        desc_default = 'Embedded Apache Tomcat running rack and rails applications'
        @trinidad_service_desc = defaults["trinidad_service_desc"] || ask(desc_ask, desc_default)
      end
      
      def configure_windows_service
        srv_path = detect_prunsrv_path

        command = %Q{//IS//#{@trinidad_service_id} --DisplayName="#{@trinidad_name}" \
--Description="#{@trinidad_service_desc}" \
--Install=#{srv_path} --Jvm=auto --StartMode=jvm --StopMode=jvm \
--StartClass=com.msp.procrun.JRubyService --StartMethod=start \
--StartParams="#{escape_path(@trinidad_daemon_path)};#{format_options(@trinidad_options)}" \
--StopClass=com.msp.procrun.JRubyService --StopMethod=stop --Classpath="#{format_options(@classpath)}" \
--StdOutput=auto --StdError=auto \
--LogPrefix="#{@trinidad_service_id.downcase}" \
++JvmOptions="#{format_options(@jruby_opts)}"
}
        system "#{srv_path} #{command}"
      end

      private

      def escape_path(path)
        path.gsub(%r{/}, '\\')
      end
      
      def format_options(options)
        options.map { |opt| escape_path(opt) }.join(';')
      end

      def default_jruby_home
        Java::JavaLang::System.get_property("jruby.home")
      end

      def default_java_home
        ENV['JAVA_HOME'] || Java::JavaLang::System.get_property("java.home")
      end
      
      def default_ruby_compat_version
        JRuby.runtime.is1_9 ? "RUBY1_9" : "RUBY1_8"
      end

      def windows?
        RbConfig::CONFIG['host_os'] =~ /mswin|mingw/i
      end

      def macosx?
        RbConfig::CONFIG['host_os'] =~ /darwin/i
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
          raise "specified path does not exist: #{jsvc_unpack_dir.inspect}"
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
        puts "configuring jsvc ..."
        command_output = `#{command}`
        if $?.exitstatus != 0
          puts command_output
          raise "`#{command}` failed with status: #{$?.exitstatus}"
        end
        
        # make
        command = "cd #{jsvc_dir} && make"
        puts "compiling jsvc ..."
        command_output = `#{command}`
        if $?.exitstatus != 0
          puts command_output
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
      
      def bundled_prunsrv_path(arch = java.lang.System.getProperty("os.arch"))
        # "amd64", "i386", "x86", "x86_64"
        path = 'windows'
        if arch =~ /amd64/i # amd64
          path += '/amd64'
        elsif arch =~ /64/i # x86_64
          path += '/ia64'
        # else "i386", "x86"
        end
        File.join(@jars_path, path, 'prunsrv.exe')
      end

      def make_path_dir(path, error = nil)
        dir = File.dirname(path)
        return if File.exist?(dir)
        begin
          FileUtils.mkdir_p dir, :mode => 0775
        rescue Errno::EACCES => e
          raise unless error
          puts "#{error} (#{e})"
        end
      end
      
      def ask_path(question, default = nil)
        path = ask(question, default)
        path.empty? ? path : File.expand_path(path)
      end

      def ask(question, default = nil)
        return default if not @stdin.tty?

        question << " [#{default}]" if default && !default.empty?

        result = nil

        while result.nil?
          @stdout.print(question + "  ")
          @stdout.flush

          result = @stdin.gets

          if result
            result.chomp!

            result = case result
            when /^$/
              default
            else
              result
            end
          end
        end
        return result
      end
      
    end
  end
end
