require File.expand_path('../spec_helper', File.dirname(__FILE__))

describe Trinidad::InitServices::WindowsStrategy do
  subject { Trinidad::InitServices::WindowsStrategy.new(StringIO.new, StringIO.new) }
  before  { subject.rbconfig({}) }
  let(:command_options) do
    {
      :jars_path        => LIB_PATH,
      :daemon_path      => '\path_to_daemon',
      :trinidad_options => ['-e production'],
      :class_path       => ['\class_path'],
      :jruby_options    => ['-J-Xmx10Gb']
    }
  end

  context "on amd64" do
    before { subject.rbconfig['arch'] = 'amd64' }
    it "is not ia64" do
      subject.should_not be_ia64
    end

    it "uses the service for amd64" do
      subject.prunsrv(LIB_PATH).should =~ /prunsrv_amd64/
    end

    it 'creates a command with all the options' do
      command = subject.service_command('Trinidad_test', 'prunsrv_amd64.exe', command_options)
      command.should =~ /--DisplayName="Trinidad_test"/
      command.should =~ /--Install="prunsrv_amd64.exe"/
      command.should =~ /--StartParams="\\path_to_daemon;-e production"/
      command.should =~ /--Classpath="\\class_path"/
      command.should =~ /--LogPrefix="trinidad_test"/
      command.should =~ /\+\+JvmOptions="-J-Xmx10Gb"/
    end
  end

  context "on i686" do
    before { subject.rbconfig['arch'] = 'i686' }
    it "is ia64" do
      subject.should be_ia64
    end

    it "uses the service for i686" do
      subject.prunsrv(LIB_PATH).should =~ /prunsrv_ia64/
    end

    it 'creates a command with all the options' do
      command = subject.service_command('Trinidad_test', 'prunsrv_i64.exe', command_options)
      command.should =~ /--DisplayName="Trinidad_test"/
      command.should =~ /--Install="prunsrv_i64.exe"/
      command.should =~ /--StartParams="\\path_to_daemon;-e production"/
      command.should =~ /--Classpath="\\class_path"/
      command.should =~ /--LogPrefix="trinidad_test"/
      command.should =~ /\+\+JvmOptions="-J-Xmx10Gb"/
    end
  end

  it "configures the windows service" do
    subject.rbconfig['arch'] = 'i686'
    subject.should_receive(:ask).and_return('Trinidad')
    service = subject.prunsrv(LIB_PATH)
    command = subject.service_command('Trinidad', service, command_options)
    subject.should_receive(:system).with("#{service} #{command}")

    subject.configure_strategy(command_options)
  end
end
