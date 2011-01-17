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

      def configure
        @app_path = ask_path('Application path?')
        @trinidad_options = ["-d #{@app_path}"]
        options_ask = 'Trinidad options?'
        options_default = '-e production'
        if windows?
          options_ask << '(separated by `;`)'
          options_default = ''
        end
        @trinidad_options << ask(options_ask, options_default)

        @jruby_home = ask_path('JRuby home?', default_jruby_home)
        @jruby_opts = ["-Djruby.home=#{@jruby_home}", "-Djruby.lib=#{File.join(@jruby_home, 'lib')}",
          "-Djruby.script=jruby", "-Djruby.daemon.module.name=Trinidad"]

        @trinidad_daemon_path = File.expand_path('../../trinidad_daemon.rb', __FILE__)
        @jars_path = File.expand_path('../../../trinidad-libs', __FILE__)

        @classpath = ['jruby-jsvc.jar', 'commons-daemon.jar'].map {|jar| File.join(@jars_path, jar)}
        @classpath << File.join(@jruby_home, 'lib', 'jruby.jar')

        if windows?
          configure_windows_service
        else
          configure_unix_daemon
        end

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
        command = %Q{//IS//Trinidad --DisplayName="Trinidad" \
--Install="#{prunsrv}" --Jvm=auto --StartMode=jvm --StopMode=jvm \
--StartClass=com.msp.procrun.JRubyService --StartMethod=start \
--StartParams="#{@trinidad_daemon_path};#{@trinidad_options.join(";")}" \
--StopClass=com.msp.procrun.JRubyService --StopMethod=stop --Classpath="#{@classpath.join(";")}" \
--StdOutput=auto --StdError=auto \
--LogPrefix="trinidad" \
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
