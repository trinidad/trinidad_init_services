require File.expand_path('spec_helper', File.join(File.dirname(__FILE__), '..'))

require 'yaml'
require 'fileutils'
require 'java'

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
  
  if java.lang.System.getProperty('os.name') !~ /windows/i

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
      init_file_content.should =~ /RUN_USER="#{username}"/
    end

    unless (`which make` rescue '').empty?
      
      before(:all) do
        FileUtils.rm_r "/tmp/jsvc-unix-src" if File.exist? "/tmp/jsvc-unix-src"
      end
      
      it "configures and compiles jsvc" do
        config_options = config_defaults.merge 'jsvc_path' => nil
        config_options['jsvc_unpack_dir'] = '/tmp'
        
        java_home = java.lang.System.get_property("java.home")
        java_home = java_home[0...-4] if java_home[-4..-1] == '/jre'
        config_options['java_home'] = java_home # need a JDK dir
        
        subject = Trinidad::InitServices::Configuration.new
        subject.instance_eval do # a bit of stubbing/mocking :
          def detect_jsvc_path; nil; end
          def ask_path(path, default = nil) 
            raise path unless path =~ /path to jsvc .*/; default
          end
        end
        
        subject.configure(config_options)

        init_file_content = File.read(init_file) rescue ''
        init_file_content.should =~ /JSVC=\/tmp\/jsvc\-unix\-src\/jsvc/
      end
      
    end
    
  end
  
	it "resolves bundled bundled prunsrv.exe based on system arch" do
    trinidad_libs = File.expand_path('trinidad-libs', File.join(File.dirname(__FILE__), '../..'))
    subject = Trinidad::InitServices::Configuration.new
    subject.initialize_paths
    
    path = subject.send :bundled_prunsrv_path, "amd64"
    path.should == File.join(trinidad_libs, 'windows/amd64/prunsrv.exe')

    path = subject.send :bundled_prunsrv_path, "x86_64"
    path.should == File.join(trinidad_libs, 'windows/ia64/prunsrv.exe')
    
    path = subject.send :bundled_prunsrv_path, "i386"
    path.should == File.join(trinidad_libs, 'windows/prunsrv.exe')
    
    path = subject.send :bundled_prunsrv_path, "x86"
    path.should == File.join(trinidad_libs, 'windows/prunsrv.exe')
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