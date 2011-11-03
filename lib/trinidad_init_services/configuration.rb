module Trinidad
  module InitServices
    require 'fileutils'
    require 'java'
    require 'trinidad_init_services/term'
    require 'trinidad_init_services/rb_config'

    class Configuration
      include Trinidad::InitServices::RbConfig

      def self.init(stdin = STDIN, stdout = STDOUT)
        strategy = windows? ? WindowsStrategy : UnixStrategy
        strategy.new(stdin, stdout)
      end

      def initialize(stdin = STDIN, stdout = STDOUT)
        @term = Term.new(stdin, stdout)
      end

      def init_options(jruby_home)
        opts = {
          :jruby_home  => jruby_home,
          :daemon_path => File.expand_path(File.join('..', 'trinidad_init_services.rb'), base_dir),
          :jars_path   => File.join(base_dir, 'services')
        }

        class_path = ['jruby-jsvc.jar', 'commons-daemon.jar'].map { |jar| File.join(opts[:jars_path], jar) }
        class_path << File.join(jruby_home, 'lib', 'jruby.jar')
        opts[:class_path] = class_path
        opts
      end

      def configure_jruby_opts(jruby_home, compat_version)
        opts = [
          "-Djruby.home=#{jruby_home}",
          "-Djruby.lib=#{File.join(jruby_home, 'lib')}",
          "-Djruby.script=jruby",
          "-Djruby.daemon.module.name=Trinidad",
          "-Djruby.compat.version=#{compat_version}"
        ]
      end

      def configure
        jruby_home = ask_path('JRuby home?', default_jruby_home)
        compat_version = ask('Ruby 1.8.x or 1.9.x compatibility?', "RUBY1_8")

        global_options = init_options(jruby_home)
        global_options[:compat_version] = compat_version
        global_options[:jruby_options]  = configure_jruby_opts(jruby_home, compat_version)
        global_options[:app_path]       = ask_path('Application path?')

        trinidad_options = ["-d #{@app_path}"]
        trinidad_options << ask(@strategy.trinidad_options_question, '-e production')
        global_options[:trinidad_options]

        configure_strategy(global_options, trinidad_default_options)
        puts 'Done.'
      end

      private

      def base_dir
        File.dirname(__FILE__)
      end

      def default_jruby_home
        Java::JavaLang::System.get_property("jruby.home")
      end

      def self.windows?
        rbconfig['host_os'] =~ /mswin|mingw/i
      end

      def ask(question, default = nil)
        term.ask(question, default)
      end

      def ask_path(question, default = nil)
        term.ask_path(question, default)
      end
    end

    require 'trinidad_init_services/unix_strategy'
    require 'trinidad_init_services/windows_strategy'
  end
end
