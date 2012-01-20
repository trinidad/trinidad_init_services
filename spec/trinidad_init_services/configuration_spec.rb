require File.dirname(__FILE__) + '/../spec_helper'
require 'yaml'
require 'rbconfig'

describe Trinidad::InitServices::Configuration do
  
  before :each do
    Dir.mkdir(tmp_dir) unless File.exist?(tmp_dir)
    Dir.mkdir(init_dir)
  end

  after :each do
    FileUtils.rm_r init_dir
    Dir.rmdir(tmp_dir) if Dir.entries(tmp_dir) == [ '.', '..' ]
  end

	it "creates the init.d file" do
    subject.configure(config_defaults)
    
		File.exist?(init_file).should be_true

    init_file_content = File.read(init_file)

    init_file_content.match(/JSVC=tmp\/jsvc/).should be_true
    init_file_content.match(/JAVA_HOME=tmp\/java/).should be_true
    init_file_content.match(/JRUBY_HOME=tmp\/jruby/).should be_true
    init_file_content.match(/APP_PATH=tmp\/app/).should be_true
    init_file_content.match(/TRINIDAD_OPTS="-d tmp\/app -e production"/).should be_true
    
    init_file_content.match(/RUN_USER=""/).should be_true
  end

  it "makes pid_file and log_file dirs" do
    pids_dir = File.join(tmp_dir, "pids")
    logs_dir = File.join(tmp_dir, "logs")
    begin
      subject.configure(
        config_defaults.merge 'pid_file' => "tmp/pids/trinidad.pid", 'log_file' => "tmp/logs/trinidad.log"
      )
      
      File.exist?(pids_dir).should be_true
      File.directory?(pids_dir).should be_true
      Dir.entries(pids_dir).should == ['.', '..']

      File.exist?(logs_dir).should be_true
      File.directory?(logs_dir).should be_true
      Dir.entries(logs_dir).should == ['.', '..']
    ensure
      Dir.rmdir(pids_dir) if File.exist?(pids_dir)
      Dir.rmdir(logs_dir) if File.exist?(logs_dir)
    end
  end
  
  if RbConfig::CONFIG['host_os'] !~ /mswin|mingw/i

    it "fails for non-existing run user" do
      username = random_username
      lambda { 
        subject.configure(config_defaults.merge 'run_user' => username) 
      }.should raise_error(ArgumentError)
    end
    
    it "sets valid run user" do
      username = `whoami`.chomp
      subject.configure(config_defaults.merge 'run_user' => username)

      init_file_content = File.read(init_file) rescue ''
      init_file_content.match(/RUN_USER="#{username}"/).should be_true
    end
    
  end
  
  private
  
    def config_defaults
      YAML::load %Q{
app_path: "tmp/app"
trinidad_options: "-e production"
jruby_home: "tmp/jruby"
ruby_compat_version: RUBY1_8
trinidad_name: Trinidad
jsvc_path: "tmp/jsvc"
java_home: "tmp/java"
output_path: "tmp/etc_init.d"
pid_file: "tmp/trinidad.pid"
log_file: "tmp/trinidad.log"
run_user: ""
}
    end
  
    def init_file
      File.join init_dir, 'trinidad'
    end

    def init_dir
      File.join tmp_dir, 'etc_init.d'
    end

    def tmp_dir
      File.join root_dir, 'tmp'
    end

    def root_dir
      File.join File.dirname(__FILE__), "/../../"
    end
    
    def random_username(len = 8)
      (0...len).map{ ( 65 + rand(25) ).chr }.join.downcase
    end
    
end