require File.expand_path('../spec_helper', File.dirname(__FILE__))

require 'yaml'
require 'fileutils'
require 'java'

describe Trinidad::InitServices::Configuration do

  before :each do
    ENV['JAVA_HOME'] = nil # make sure it does not interfere
    Dir.mkdir(tmp_dir) unless File.exist?(tmp_dir)
    Dir.mkdir(init_dir)
  end

  after :each do
    FileUtils.rm_r init_dir
    Dir.rmdir(tmp_dir) if Dir.entries(tmp_dir) == [ '.', '..' ]
    ENV_JAVA.clear; ENV_JAVA.update @@env_java
  end

  before(:all) { @@env_java = ENV_JAVA.dup }

  before(:each) { subject.ask = false } # do not ask by default

	it "creates the init.d file" do
    subject.configure config_defaults.merge 'java_home' => 'tmp/java', 'jruby_home' => 'tmp/jruby'

		expect( File.exist?(init_file) ).to be true

    init_file_content = File.read(init_file)

    expect( init_file_content ).to match(/JSVC=tmp\/jsvc\/bin\/jsvc/)
    expect( init_file_content ).to match(/JAVA_HOME="tmp\/java"/)
    expect( init_file_content ).to match(/JRUBY_HOME="tmp\/jruby"/)
    expect( init_file_content ).to match(/BASE_PATH="tmp\/app"/)

    expect( init_file_content ).to match(/PID_FILE="tmp\/trinidad.pid"/)
    expect( init_file_content ).to match(/OUT_FILE="tmp\/trinidad.out"/)

    expect( init_file_content ).to match(/TRINIDAD_OPTS="--dir tmp\/app -e production"/)

    expect( init_file_content ).to match(/RUN_USER=""/)
  end

	it "creates a (source) valid init.d file" do
    subject.configure config_defaults.merge 'java_opts' => '-Xmx512M -Xss1024k'

		expect( File.exist?(init_file) ).to be true

    fail('not a valid bash source (see output above)') unless system "bash -n #{init_file}"

  end unless (`which bash` rescue '').chomp.empty?

	it "configures memory requirements using JAVA_OPTS (Java 6)" do
    ENV_JAVA['java.version'] = '1.6.0_43'
    ENV_JAVA['os.arch'] = 'x64'

    defaults = config_defaults.merge 'configure_memory' => true, 'hot_deployment' => true
    subject.configure(defaults)

    init_file_content = File.read(init_file)

    java_opts = init_file_content.match(/JAVA_OPTS="(.*?)"/m)
    expect( java_opts ).to_not be nil
    expect( java_opts = java_opts[1] ).to_not be nil
    expect( java_opts ).to include '-XX:+UseCodeCacheFlushing'
    expect( java_opts ).to include '-XX:ReservedCodeCacheSize='
    expect( java_opts ).to include '-XX:MaxPermSize='
    expect( java_opts ).to_not include '-XX:MaxMetaspaceSize='
    expect( java_opts ).to include '-Xmx'

    expect( java_opts ).to include '-XX:+UseConcMarkSweepGC'
    expect( java_opts ).to include '-XX:+UseConcMarkSweepGC'
    expect( java_opts ).to include '-XX:+UseCompressedOops'
  end

	it "configures memory requirements using JAVA_OPTS (Java 8)" do
    ENV_JAVA['java.version'] = '1.8.0_05'
    ENV_JAVA['os.arch'] = 'x64'

    defaults = config_defaults.merge 'configure_memory' => true
    subject.configure(defaults)

    init_file_content = File.read(init_file)

    java_opts = init_file_content.match(/JAVA_OPTS="(.*?)"/m)
    expect( java_opts ).to_not be nil
    expect( java_opts = java_opts[1] ).to_not be nil
    expect( java_opts ).to include '-XX:+UseCodeCacheFlushing'
    expect( java_opts ).to include '-XX:ReservedCodeCacheSize='
    expect( java_opts ).to include '-XX:MaxMetaspaceSize='
    expect( java_opts ).to include '-Xmx'

    expect( java_opts ).to_not include '-XX:+UseConcMarkSweepGC'
    expect( java_opts ).to_not include '-XX:+UseCompressedOops'
  end

	it "calculates memory requirements using JAVA_OPTS" do
    defaults = config_defaults.merge 'configure_memory' => true
    subject.configure(defaults)

    init_file_content = File.read(init_file)

    java_opts = init_file_content.match(/JAVA_OPTS="(.*?)"/m)[1]
    expect( java_opts ).to_not be nil
    expect( code_cache_size = java_opts.match(/-XX:ReservedCodeCacheSize=(.*)m/)[1] ).to_not be nil
    if java_version =~ /^1\.(6|7)/
      expect( max_perm_size = java_opts.match(/-XX:MaxPermSize=(.*)m/)[1] ).to_not be nil
    else
      expect( max_perm_size = java_opts.match(/-XX:MaxMetaspaceSize=(.*)m/)[1] ).to_not be nil
    end
    expect( max_heap_size = java_opts.match(/-Xmx(.*)m/)[1] ).to_not be nil

    total = code_cache_size.to_i + max_perm_size.to_i + max_heap_size.to_i

    expect( 720 - total ).to be >= 0
    expect( 720 - total ).to be <= 10
  end

	it "configures -Xmx for custom JAVA_HOME" do
    defaults = config_defaults.merge 'configure_memory' => true, 'java_home' => '/opt/ibm/jre-5'
    subject.configure(defaults)

    init_file_content = File.read(init_file)

    expect( init_file_content.match(/JAVA_OPTS=(.*)$/) ).to_not be nil
    expect( init_file_content.match(/JAVA_OPTS=(.*)$/) ).to_not eql '-Xmx670m'
  end

  it "makes pid_file and log_file dirs" do
    pids_dir = File.join(tmp_dir, "pids")
    logs_dir = File.join(tmp_dir, "logs")
    begin
      config = config_defaults.dup; config.delete('out_file')
      config.merge! 'pid_file' => "tmp/pids/trinidad.pid", 'log_file' => "tmp/logs/trinidad.out"
      subject.configure(config)

      expect( File.exist?(pids_dir) ).to be true
      expect( File.directory?(pids_dir) ).to be true
      expect( Dir.entries(pids_dir) ).to eql ['.', '..']

      expect( File.exist?(logs_dir) ).to be true
      expect( File.directory?(logs_dir) ).to be true
      expect( Dir.entries(logs_dir) ).to eql ['.', '..']
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

    unless (`which make` rescue '').chomp.empty?

      before(:all) do
        FileUtils.rm_r "/tmp/jsvc-unix-src" if File.exist? "/tmp/jsvc-unix-src"
      end

      it "configures and compiles jsvc" do
        config_options = config_defaults.merge 'jruby_home' => '/opt/jruby'
        config_options['jsvc_path'] = nil
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
      end unless ENV['SKIP_JSVC'] == 'true'

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

  let(:windows_configuration) do
    subject = Trinidad::InitServices::Configuration.new
    subject.instance_eval do
      def windows?; true end
      def macosx?; false end
      def service_listed_windows?(service); false end
      def system(command); @system_command = command end
      def system_command; @system_command end
      def log_command(command); end
    end
    subject
  end

  it "configures windows service" do
    subject = windows_configuration
    config_options = {
      'app_path' => "C:/MyApp",
      'ruby_compat_version' => "1.9",
      'service_id' => "TrinidadService",
      'service_name' => "Trinidad",
      'service_desc' => "Trinidad Service Description",
      'trinidad_options' => "-e production -p 4242 ",
      'java_home' => "C:/Program Files (x86)/jdk-1.7.0",
      'jruby_home' => "C:/Program Files/jruby",
    }
    subject.configure(config_options)
    ( system_command = subject.system_command ).should_not be nil
    system_command.should =~ /\/\/IS\/\/TrinidadService/
    system_command.should =~ /--DisplayName="Trinidad"/
    system_command.should =~ /--Description="Trinidad Service Description"/
    system_command.should =~ /--StartParams=".*?\\daemon.rb;--dir;C:\\MyApp;-e;production;-p;4242"/
    system_command.should =~ /--Classpath=".*?\\jruby-jsvc.jar;.*?\\commons-daemon.jar;.*?\\jruby.jar/
    system_command.should =~ /--JavaHome="C\:\\Program Files \(x86\)\\jdk-1\.7\.0"/
    system_command.should =~ %r{
      \+\+JvmOptions="
        -Djruby.home=C:\\Program\ Files\\jruby;
        -Djruby.lib=C:\\Program\ Files\\jruby\\lib;
        -Djruby.script=jruby;
        -Djruby.daemon.module.name=Trinidad;
        -Djruby.compat.version=RUBY1_9
      "
    }x
  end

  it "configures windows service log out/err/pid" do
    subject = windows_configuration
    config_options = {
      'app_path' => "C:/MyApp",
      'log_path' => "C:/MyApp/log",
      'out_file' => "C:/MyApp/log/STD.out",
    }
    subject.configure(config_options)
    ( system_command = subject.system_command ).should_not be nil
    system_command.should =~ /\/\/IS\/\/Trinidad/
    system_command.should =~ /--DisplayName="Trinidad"/
    system_command.should =~ /--StdOutput="C\:\\MyApp\\log\\STD.out"/
    system_command.should =~ /--StdError="C\:\\MyApp\\log\\STD.out"/
    system_command.should =~ /--PidFile=Trinidad.pid/
  end

  it "updates windows service when installed" do
    subject = windows_configuration
    subject.instance_eval do
      def service_listed_windows?(service); service == 'Trinidad' end
    end
    config_options = {
      'app_path' => "C:/MyApp",
    }
    subject.configure(config_options)
    ( system_command = subject.system_command ).should_not be nil
    expect( system_command ).to match /\/\/US\/\/Trinidad/
  end

  it "uninstalls windows service" do
    subject = windows_configuration
    subject.uninstall
    ( system_command = subject.system_command ).should_not be nil
    expect( system_command ).to match /\/\/DS\/\/Trinidad/
  end

	it "ask_path works when non tty and default nil" do
    subject.ask = false
    stdin = mock('stdin')
    stdin.stubs(:tty?).returns false
    subject.instance_variable_set(:@stdin, stdin)
    subject.send(:ask_path, 'Home', nil).should be nil
  end

	it "ask_path raises when non tty and default false" do
    subject.ask = false
    stdin = mock('stdin')
    stdin.stubs(:tty?).returns false
    subject.instance_variable_set(:@stdin, stdin)
    expect( lambda {
      subject.send(:ask_path, 'Home', false)
    } ).to raise_error RuntimeError
  end

	it "ask= forces trinidad to not ask on tty" do
    subject.ask = false
    outcome = subject.send :ask, 'hello?', :there
    outcome.should == :there

    outcome = subject.send :ask, 'de-ja-vu?', nil
    outcome.should be nil
  end

	it "say= silences standard output" do
    def subject.puts(msg)
      raise msg
    end
    lambda { subject.send :say, 'hello' }.should raise_error

    subject.say = false
    lambda { subject.send :say, 'hello' }.should_not raise_error
  end

  private

  def config_defaults
    YAML::load File.read(config_file_path)
  end

  def config_file_path
    File.expand_path('init_service_config.yml', File.dirname(__FILE__))
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

  def java_version
    Java::JavaLang::System.getProperty("java.version")
  end

end