module Trinidad
  module InitServices
    require 'rbconfig'

    module RbConfig
      def rbconfig(config = ::RbConfig::CONFIG)
        @rb_config ||= config
      end
    end
  end
end
