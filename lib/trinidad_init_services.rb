require 'rubygems'
require 'trinidad'

module Trinidad
  module Daemon
    VERSION = '1.1.0.pre3'

    def init
    end

    def setup?
      true
    end

    def start
      opts = Trinidad::CommandLineParser.parse(ARGV)
      opts[:trap] = false
      @server = Trinidad::Server.new(opts)
      @server.start
    end

    def stop
      @server.stop
    end

    extend self
  end
end

Trinidad::Daemon.init
