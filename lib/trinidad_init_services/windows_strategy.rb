module Trinidad
  module InitServices
    class WindowsStrategy < Configuration

      def configure_strategy(options)
        service_name = ask('Windows service name? {Alphanumeric and spaces only}', 'Trinidad')
        service = prunsrv(options[:jars_path])

        command = service_command(service_name, service, options)
        unless options[:test]
          system "#{service} #{command}"
        else
          puts 'Testing init service:'
          puts service, command
        end
      end

      def service_command(service_name, service, options)
        class_path = format(options[:class_path])
        trinidad_options = format(options[:trinidad_options])
        jruby_options = format(options[:jruby_options])
        daemon_path = path_to options[:daemon_path]
        service_path = path_to service

        %Q{//IS//#{service_name.gsub(/\W/, '')} --DisplayName="#{service_name}" \
--Install="#{service_path}" --Jvm=auto --StartMode=jvm --StopMode=jvm \
--StartClass=com.msp.procrun.JRubyService --StartMethod=start \
--StartParams="#{daemon_path};#{trinidad_options}" \
--StopClass=com.msp.procrun.JRubyService --StopMethod=stop --Classpath="#{class_path}" \
--StdOutput=auto --StdError=auto \
--LogPrefix="#{service_name.downcase.gsub(/\W/,'')}" \
++JvmOptions="#{jruby_options}"
}
      end

      def trinidad_options_question
        'Trinidad options? (separated by `;`)'
      end

      def prunsrv(jars_path)
        prunsrv_path = 'prunsrv_' + (ia64? ? 'ia64' : 'amd64') + '.exe'
        File.expand_path(prunsrv_path, jars_path)
      end

      def ia64?
        rbconfig['arch'] =~ /i686|ia64/i
      end

      def path_to(option)
        option.gsub(%r{/}, '\\') # yay, windows!!
      end

      def format(options)
        options.map{|c| path_to(c)}.join(';')
      end
    end
  end
end
