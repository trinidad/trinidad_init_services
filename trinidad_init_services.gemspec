# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require 'trinidad_init_services/version'

Gem::Specification.new do |s|
  s.name              = 'trinidad_init_services'
  s.version           = Trinidad::InitServices::VERSION
  s.rubyforge_project = 'trinidad_init_services'
  
  s.summary     = "Trinidad init service scripts based on Apache Commons Daemon"
  s.description = "Trinidad init service scripts on Apache Commons Daemon and JRuby-Jsvc, compatible with Unix and Windows services"
  
  s.authors  = ["David Calavera"]
  s.email    = 'calavera@apache.org'
  s.homepage = 'http://github.com/trinidad/trinidad_init_services'

  ## This gets added to the $LOAD_PATH so that 'lib/NAME.rb' can be required as
  ## require 'NAME.rb' or'/lib/NAME/file.rb' can be as require 'NAME/file.rb'
  s.require_paths = %w[lib]

  ## If your gem includes any executables, list them here.
  s.executables = ["trinidad_init_service"]
  s.default_executable = 'trinidad_init_service'

  ## Specify any RDoc options here. You'll want to add your README and
  ## LICENSE files to the extra_rdoc_files list.
  s.rdoc_options = ["--charset=UTF-8"]
  s.extra_rdoc_files = %w[ README.md LICENSE ]

  ## List your runtime dependencies here. Runtime dependencies are those
  ## that are needed for an end user to actually USE your code.
  s.add_dependency('trinidad', '>= 1.3.5')

  s.add_development_dependency('rspec', '>= 2.10')
  s.add_development_dependency('mocha', '>= 0.10')
  
  s.files = `git ls-files`.split("\n")

  ## Test files will be grabbed from the file list. Make sure the path glob
  ## matches what you actually use.
  ## s.test_files = s.files.select { |path| path =~ /^test\/test_.*\.rb/ }

  s.post_install_message = <<TEXT

--------------------------------------------------------------------------------

Please now run:

  $ jruby -S trinidad_init_service

to complete the installation.

--------------------------------------------------------------------------------

TEXT
end
