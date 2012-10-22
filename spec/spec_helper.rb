begin
  require 'rspec'
rescue LoadError => e
  require('rubygems') && retry
  raise e
end

require 'mocha'

RSpec.configure do |config|
  config.mock_with :mocha
end

$:.unshift File.expand_path('../lib', File.dirname(__FILE__))

require 'trinidad_init_services'
require 'trinidad/daemon'
