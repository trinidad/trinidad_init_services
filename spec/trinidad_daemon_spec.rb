require File.expand_path('spec_helper', File.dirname(__FILE__))
require 'trinidad_init_services'

Trinidad::Daemon.module_eval do
  def server; @server; end
end

describe Trinidad::Daemon do

  after :each do
    Trinidad.configuration = nil
  end
  
  it "starts a configured server" do
    Trinidad::Server.any_instance.expects(:start)
    Trinidad::Daemon.start([])
    Trinidad::Daemon.server.should be_a(Trinidad::Server)
    Trinidad::Daemon.server.config.should be_a(Trinidad::Configuration)
  end

  context "started with a yaml config" do
    
    before :each do
      Trinidad::Server.any_instance.stubs(:start)
      config = File.expand_path('stubs/trinidad.yml', File.dirname(__FILE__))
      Trinidad::Daemon.start([ '--config', config ])
      @config = Trinidad::Daemon.server.config
    end
    
    it "is configured without signal trap" do
      @config[:trap].should == false
    end

    it "is configured according to .yml" do
      @config[:port].should == 3001
      @config[:context_path].should == '/foo'
      @config[:jruby_min_runtimes].should == 1
      @config[:jruby_max_runtimes].should == 1
      
      @config[:address].should == 'localhost'
    end
    
  end

  context "started with a ruby config" do
    
    before :each do
      Trinidad::Server.any_instance.stubs(:start)
      config = File.expand_path('stubs/trinidad.rb', File.dirname(__FILE__))
      Trinidad::Daemon.start([ '--config', config ])
      @config = Trinidad::Daemon.server.config
    end
    
    it "is configured without signal trap" do
      @config[:trap].should == false
    end

    it "is configured according to .rb" do
      @config[:port].should == 3002
      @config[:address].should == '127.0.0.1'
      @config[:jruby_min_runtimes].should == 1
      @config[:jruby_max_runtimes].should == 2
      
      @config[:context_path].should == '/'
    end
    
  end
  
end