module Trinidad
  module InitServices
    class UnixStrategy < Configuration
      require 'erb'

      def configure_strategy(options)
        @options = options.dup
        @options[:jsvc] = jsvc_path(options[:jars_path])
        @options[:java_home] = ask_path('Java home?', default_java_home)
        output_path = ask_path('init.d output path?', '/etc/init.d')
        @options[:pid_file] = ask_path('pid file?', '/var/run/trinidad.pid')
        @options[:log_file] = ask_path('log file?', '/var/log/trinidad.log')

        render_template(output_path)
      end

      def render_template(output_path)
        daemon = ERB.new(init_template).result(binding)

        unless @options[:test]
          puts "Moving trinidad to #{output_path}"
          tmp_file = "#{output_path}/trinidad"
          File.open(tmp_file, 'w') do |file|
            file.write(daemon)
          end

          FileUtils.chmod(0744, tmp_file)
        else
          puts 'Testing init service:'
          puts daemon
        end
      end

      def init_template
        File.read(File.expand_path('../../init.d/trinidad.erb', File.dirname(__FILE__)))
      end

      def trinidad_options_question
        'Trinidad options?'
      end

      def default_java_home
        Java::JavaLang::System.get_property("java.home")
      end

      def jsvc_path(jars_path)
        jsvc = 'jsvc_' + (macosx? ? 'darwin' : 'linux')
        File.join(jars_path, jsvc)
      end

      def macosx?
        rbconfig['host_os'] =~ /darwin/i
      end
    end
  end
end
