module Trinidad
  module Daemon
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
        @trinidad_daemon_path = File.expand_path('../../trinidad_daemon.rb', __FILE__)
        @jars_path = File.expand_path('../../../trinidad-libs', __FILE__)

        @classpath = ['jruby-jsvc.jar', 'commons-daemon.jar'].map { |jar| File.join(@jars_path, jar) }
        @classpath << File.join(@jruby_home, 'lib', 'jruby.jar')
      end

      def collect_windows_opts(options_ask)
        options_ask << '(separated by `;`)'
        options_default = ''
        name_ask = 'Service name? {Alphanumeric and spaces only}'
        name_default = 'Trinidad'
        @trinidad_name = ask(name_ask, name_default)
        options_default
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

      def configure
        @app_path = ask_path('Application path?')
        @trinidad_options = ["-d #{@app_path}"]
        options_ask = 'Trinidad options?'
        options_default = '-e production'
        options_default = collect_windows_opts(options_ask) if windows?

        @trinidad_options << ask(options_ask, options_default)
        @jruby_home = ask_path('JRuby home?', default_jruby_home)
        @ruby_compat_version = ask('Ruby 1.8.x or 1.9.x compatibility?', default_ruby_compat_version)
        @jruby_opts = configure_jruby_opts
        initialize_paths

        windows? ? configure_windows_service : configure_unix_daemon
        puts 'Done.'
      end

      def configure_unix_daemon
        @jsvc = ask_path('Jsvc path?', `which jsvc`.chomp)
        @java_home = ask_path('Java home?', default_java_home)
        @output_path = ask_path('init.d output path?', '/etc/init.d')
        @pid_file = ask_path('pid file?', '/var/run/trinidad/trinidad.pid')
        @log_file = ask_path('log file?', '/var/log/trinidad/trinidad.log')

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
        prunsrv = File.join(@jars_path, 'prunsrv.exe')
        command = %Q{//IS//Trinidad --DisplayName="#{@trinidad_name}" \
--Install="#{prunsrv}" --Jvm=auto --StartMode=jvm --StopMode=jvm \
--StartClass=com.msp.procrun.JRubyService --StartMethod=start \
--StartParams="#{@trinidad_daemon_path};#{@trinidad_options.join(";")}" \
--StopClass=com.msp.procrun.JRubyService --StopMethod=stop --Classpath="#{@classpath.join(";")}" \
--StdOutput=auto --StdError=auto \
--LogPrefix="#{@trinidad_name.downcase.gsub(/\W/,'')}" \
++JvmOptions="#{@jruby_opts.join(";")}"
}
        system "#{prunsrv} #{command}"
      end

      private

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
        RbConfig::CONFIG['host_os'] =~ /mswin|mingw/
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