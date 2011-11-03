require File.expand_path('../spec_helper', File.dirname(__FILE__))

describe Trinidad::InitServices::UnixStrategy do
  subject { Trinidad::InitServices::UnixStrategy.new(StringIO.new, StringIO.new) }
  before  { subject.rbconfig({'host_os' => 'darwin'}) }
  let(:options) do
    {
      :jars_path        => LIB_PATH,
      :daemon_path      => '/path_to_daemon',
      :trinidad_options => ['-e production'],
      :class_path       => ['/class_path'],
      :jruby_options    => ['-J-Xmx10Gb']
    }
  end

  it "renders the init.d file" do
    subject.should_receive(:ask_path).with('Java home?', subject.default_java_home).and_return(subject.default_java_home)
    subject.should_receive(:ask_path).with('init.d output path?', '/etc/init.d').and_return('.')
    subject.should_receive(:ask_path).with('pid file?', '/var/run/trinidad.pid').and_return('./trinidad.pid')
    subject.should_receive(:ask_path).with('log file?', '/var/log/trinidad.log').and_return('./trinidad.log')
    subject.should_receive(:init_template).and_return(File.read(subject.init_template))

    FakeFS.activate!
    subject.configure_strategy(options)

    init_d = File.read('./trinidad')
    p init_d
    FakeFS.deactivate!
  end
end
