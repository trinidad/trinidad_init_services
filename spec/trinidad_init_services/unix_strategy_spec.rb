require File.expand_path('../spec_helper', File.dirname(__FILE__))

describe Trinidad::InitServices::UnixStrategy do
  subject { Trinidad::InitServices::UnixStrategy.new(StringIO.new, StringIO.new) }
  before  { subject.rbconfig({'host_os' => 'darwin'}) }
  let(:options) do
    {
      :app_path         => '/tmp/foo',
      :jars_path        => LIB_PATH,
      :daemon_path      => '/path_to_daemon',
      :trinidad_options => ['-e production', '--threadsafe'],
      :class_path       => ['/class_path', '/other_path'],
      :jruby_options    => ['-J-Xmx10Gb', '-J-Xms512m']
    }
  end

  it "renders the init.d file" do
    tmp = Dir.mktmpdir
    subject.should_receive(:ask_path).with('Java home?', subject.default_java_home).and_return(subject.default_java_home)
    subject.should_receive(:ask_path).with('init.d output path?', '/etc/init.d').and_return(tmp)
    subject.should_receive(:ask_path).with('pid file?', '/var/run/trinidad.pid').and_return('trinidad.pid')
    subject.should_receive(:ask_path).with('log file?', '/var/log/trinidad.log').and_return('trinidad.log')

    subject.configure_strategy(options)

    init_d = File.read(File.join(tmp, 'trinidad'))
    init_d.should =~ /JSVC="#{File.join(LIB_PATH, 'jsvc_darwin')}"/
    init_d.should =~ /JAVA_HOME="#{subject.default_java_home}"/
    init_d.should =~ %r{APP_PATH="/tmp/foo"}
    init_d.should =~ /RUBY_SCRIPT="#{options[:daemon_path]}"/
    init_d.should =~ /TRINIDAD_OPTS="-e production --threadsafe"/
    init_d.should =~ %r{PIDFILE="trinidad.pid"}
    init_d.should =~ %r{LOG_FILE="trinidad.log"}
    init_d.should =~ %r{CLASSPATH="/class_path:/other_path"}
    init_d.should =~ /JRUBY_CUSTOM_OPTIONS="-J-Xmx10Gb -J-Xms512m"/

  end
end
