module Trinidad
  module Daemon
    require 'erb'
    require 'java'

    class Configuration
      def initialize(stdin = STDIN, stdout = STDOUT)
        @stdin = stdin
        @stdout = stdout
      end

      def configure
        @app_path = File.expand_path(ask('Application path?'))
        @jsvc = ask('Jsvc path?', `which jsvc`.chomp)
        @java_home = ask('Java home?', default_java_home)
        @jruby_home = ask('JRuby home?', default_jruby_home)
        @output_path = ask('init.d output path?', '/etc/init.d')
        @pid_file = ask('pid file?', '/var/run/trinidad/trinidad.pid')
        @log_file = ask('log file?', '/var/log/trinidad/trinidad.log')

        @trinidad_daemon_path = File.expand_path('../../trinidad_daemon.rb', __FILE__)
        @jars_path = File.expand_path('../../../trinidad-libs', __FILE__)

        daemon = ERB.new(
          File.read(
            File.expand_path('../../init.d/trinidad_daemon.sh.erb', File.dirname(__FILE__))
          )
        ).result(binding)

        tmp_file = "#{ENV['TMP_DIR']}/trinidad-daemon.sh"
        File.open(tmp_file, 'w') do |file|
          file.write(daemon)
        end

        puts "Moving trinidad-daemon.sh to #{@output_path}"
        `cp #{tmp_file} #{@output_path}`
        puts 'Done.'
      end

      private
      def default_jruby_home
        Java::JavaLang::System.get_property("jruby.home")
      end

      def default_java_home
        Java::JavaLang::System.get_property("java.home")
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
