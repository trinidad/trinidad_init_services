require File.expand_path('spec_helper', File.join(File.dirname(__FILE__), '..'))
require 'yaml'

describe Trinidad::InitServices::Configuration do

  before do
    Dir.mkdir(tmp_dir) unless File.exist?(tmp_dir)
    Dir.mkdir(init_dir) 
    
    config = <<YAML
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
YAML

    defaults = YAML::load(config)

    subject.configure(defaults)
  end

  after do
    File.delete(init_file)
    Dir.rmdir(init_dir)
    Dir.rmdir(tmp_dir)
  end

	it "is creates the init.d file" do
		File.exist?(init_file).should be_true

    init_file_content = File.read(init_file)

    init_file_content.match(/JSVC=tmp\/jsvc/).should be_true
    init_file_content.match(/JAVA_HOME=tmp\/java/).should be_true
    init_file_content.match(/JRUBY_HOME=tmp\/jruby/).should be_true
    init_file_content.match(/APP_PATH=tmp\/app/).should be_true
    init_file_content.match(/TRINIDAD_OPTS="-d tmp\/app -e production"/).should be_true
  end

  def init_file
    "#{init_dir}/trinidad"
  end

  def init_dir
    "#{tmp_dir}/etc_init.d/"
  end

  def tmp_dir
    "#{root_dir}/tmp"
  end

  def root_dir
    File.dirname(__FILE__) + "/../../"
  end
end