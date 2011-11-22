begin
  require 'rspec'
rescue LoadError
  require 'rubygems'
  gem 'rspec'
  require 'rspec'
end

$:.unshift(File.dirname(__FILE__) + '/../lib')

require 'trinidad_init_services/configuration'

require 'java'
require 'mocha'
require 'fileutils'

RSpec.configure do |config|
  config.mock_with :mocha
end
