module Trinidad
  module InitServices
    require 'erb'
    require 'java'
    require 'rbconfig'
    require 'fileutils'

    class Configuration
      def initialize(stdin = STDIN, stdout = STDOUT)
        @stdin = stdin
        @stdout = stdout
      end

      def initialize_paths
        @trinidad_daemon_path = File.expand_path('../../trinidad_init_services.rb', __FILE__)
        @jars_path = File.expand_path('../../../trinidad-libs', __FILE__)

        @classpath = ['jruby-jsvc.jar', 'commons-daemon.jar'].map { |jar| File.join(@jars_path, jar) }
        @classpath << File.join(@jruby_home, 'lib', 'jruby.jar')
      end

      def collect_windows_opts(options_ask, defaults)
        options_ask << '(separated by `;`)'
        name_ask = 'Service name? {Alphanumeric and spaces only}'
        name_default = 'Trinidad'
        @trinidad_name = defaults["trinidad_name"] || ask(name_ask, name_default)
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
        @jruby_home = defaults["jruby_home"] || ask_path('JRuby home?', default_jruby_home)
        @ruby_compat_version = defaults["ruby_compat_version"] || ask('Ruby 1.8.x or 1.9.x compatibility?', default_ruby_compat_version)
        @jruby_opts = configure_jruby_opts
        initialize_paths

        windows? ? configure_windows_service : configure_unix_daemon(defaults)
        puts 'Done.'
      end

      def configure_unix_daemon(defaults)
        @jsvc = defaults["jsvc_path"] || jsvc_path
        @java_home = defaults["java_home"] || ask_path('Java home?', default_java_home)
        @output_path = defaults["output_path"] || ask_path('init.d output path?', '/etc/init.d')
        @pid_file = defaults["pid_file"] || ask_path('pid file?', '/var/run/trinidad/trinidad.pid')
        @log_file = defaults["log_file"] || ask_path('log file?', '/var/log/trinidad/trinidad.log')
        @run_user = defaults["run_user"] || ask_path('run daemon as user?', '')
        
        @run_user.strip!
        if @run_user != '' && `id -u #{@run_user}` == ''
          raise ArgumentError, "'#{@run_user}' does not exist"
        end
        
        daemon = ERB.new(
          File.read(
            File.expand_path('../../init.d/trinidad.erb', File.dirname(__FILE__))
          )
        ).result(binding)

        puts "Moving trinidad to #{@output_path}"
        tmp_file = "#{@output_path}/trinidad"
        File.open(tmp_file, 'w') do |file|
          file.write(daemon)
        end

        FileUtils.chmod(0744, tmp_file)
      end

      def configure_windows_service
        srv_path = prunsrv_path
        trinidad_service_id = @trinidad_name.gsub(/\W/, '')

        command = %Q{//IS//#{trinidad_service_id} --DisplayName="#{@trinidad_name}" \
--Install=#{srv_path} --Jvm=auto --StartMode=jvm --StopMode=jvm \
--StartClass=com.msp.procrun.JRubyService --StartMethod=start \
--StartParams="#{escape(@trinidad_daemon_path)};#{format_path(@trinidad_options)}" \
--StopClass=com.msp.procrun.JRubyService --StopMethod=stop --Classpath="#{format_path(@classpath)}" \
--StdOutput=auto --StdError=auto \
--LogPrefix="#{trinidad_service_id.downcase}" \
++JvmOptions="#{format_path(@jruby_opts)}"
}
        system "#{srv_path} #{command}"
      end

      private

      def escape(path)
        path.gsub(%r{/}, '\\')
      end

      def format_path(option)
        option.map {|o| escape(o)}.join(';')
      end

      def default_jruby_home
        Java::JavaLang::System.get_property("jruby.home")
      end

      def default_java_home
        Java::JavaLang::System.get_property("java.home")
      end

      def default_ruby_compat_version
        "RUBY1_8"
      end

      def windows?
        RbConfig::CONFIG['host_os'] =~ /mswin|mingw/i
      end

      def macosx?
        RbConfig::CONFIG['host_os'] =~ /darwin/i
      end

      def ia64?
        RbConfig::CONFIG['arch'] =~ /i686|ia64/i
      end

      def jsvc_path
        jsvc = 'jsvc_' + (macosx? ? 'darwin' : 'linux')
        File.join(@jars_path, jsvc)
      end

      def prunsrv_path
        prunsrv = 'prunsrv_' + (ia64? ? 'ia64' : 'amd64') + '.exe'
        File.join(@jars_path, prunsrv)
      end

      def ask_path(question, default = nil)
        File.expand_path(ask(question, default))
      end

      def ask(question, default = nil)
        return nil if not @stdin.tty?

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
