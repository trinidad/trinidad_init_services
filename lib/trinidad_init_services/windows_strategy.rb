module Trinidad
  module InitServices
    class WindowsStrategy < Configuration
      require 'escape'

      def configure_strategy(options)
        service_name = ask('Windows service name? {Alphanumeric and spaces only}', 'Trinidad')
        service = prunsrv(options[:jars_path])

        command = service_command(service_name, service, options)
        unless options[:test]
          system Escape.shell_command("#{service} #{command}")
        else
          puts 'Testing init service:'
          puts service, command
        end
      end

      def service_command(service_name, service, options)
        %Q{//IS//Trinidad --DisplayName="#{service_name}" \
--Install="#{service}" --Jvm=auto --StartMode=jvm --StopMode=jvm \
--StartClass=com.msp.procrun.JRubyService --StartMethod=start \
--StartParams="#{options[:daemon_path]};#{options[:trinidad_options].join(";")}" \
--StopClass=com.msp.procrun.JRubyService --StopMethod=stop --Classpath="#{options[:class_path].join(";")}" \
--StdOutput=auto --StdError=auto \
--LogPrefix="#{service_name.downcase.gsub(/\W/,'')}" \
++JvmOptions="#{options[:jruby_options].join(";")}"
}
      end

      def trinidad_options_question
        'Trinidad options? (separated by `;`)'
      end

      def prunsrv(jars_path)
        prunsrv_path = 'prunsrv_' + (ia64? ? 'ia64' : 'amd64') + '.exe'
        File.join(jars_path, prunsrv_path)
      end

      def ia64?
        rbconfig['arch'] =~ /i686|ia64/i
      end
    end
  end
end
