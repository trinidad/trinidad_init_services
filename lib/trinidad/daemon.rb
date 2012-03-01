require 'rubygems'
require 'trinidad'

module Trinidad
  module Daemon
    require 'trinidad_init_services/version'
    VERSION = Trinidad::InitServices::VERSION

    def init
    end

    def setup?
      true
    end

    def start(args = ARGV)
      Trinidad::CommandLineParser.parse(args)
      Trinidad.configuration.trap = false
      @server = Trinidad::Server.new
      @server.start
    end

    def stop
      @server.stop
    end

    extend self
  end
end

Trinidad::Daemon.init
