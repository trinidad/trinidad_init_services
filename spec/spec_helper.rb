begin
  require 'rspec'
rescue LoadError
  require 'rubygems'
  gem 'rspec'
  require 'rspec'
end

require 'mocha'

RSpec.configure do |config|
  config.mock_with :mocha
end

$:.unshift(File.dirname(__FILE__) + '/../lib')

require 'trinidad_init_services'
require 'trinidad/daemon'
