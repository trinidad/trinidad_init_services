begin
  require 'bundler/gem_helper'
rescue LoadError => e
  require('rubygems') && retry
  raise e
end
Bundler::GemHelper.install_tasks
task :gem => :build

task :default => :spec

require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec) do |spec|
  spec.rspec_opts = ['--color', "--format documentation"]
end
