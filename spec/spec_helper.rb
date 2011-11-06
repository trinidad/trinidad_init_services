require 'rspec'
require 'tmpdir'

$LOAD_PATH << '../lib'
require 'trinidad_init_services/configuration'

LIB_PATH = File.expand_path('../lib/trinidad_init_services/services', File.dirname(__FILE__))

RSpec.configure
