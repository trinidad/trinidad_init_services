module Trinidad
  module InitServices
    require 'rbconfig'

    module RbConfig
      def self.included(receiver)
        receiver.extend(self)
      end

      def rbconfig(config = ::RbConfig::CONFIG)
        @rb_config ||= config
      end
    end
  end
end
