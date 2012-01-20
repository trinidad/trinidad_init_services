## This is the rakegem gemspec template. Make sure you read and understand
## all of the comments. Some sections require modification, and others can
## be deleted if you don't need them. Once you understand the contents of
## this file, feel free to delete any comments that begin with two hash marks.
## You can find comprehensive Gem::Specification documentation, at
## http://docs.rubygems.org/read/chapter/20
Gem::Specification.new do |s|
  s.specification_version = 2 if s.respond_to? :specification_version=
  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.rubygems_version = '1.3.5'

  ## Leave these as is they will be modified for you by the rake gemspec task.
  ## If your rubyforge_project name is different, then edit it and comment out
  ## the sub! line in the Rakefile
  s.name              = 'trinidad_init_services'
  s.version           = '1.1.2'
  s.date              = '2012-01-17'
  s.rubyforge_project = 'trinidad_init_services'

  ## Make sure your summary is short. The description may be as long
  ## as you like.
  s.summary     = "Trinidad init service scripts based on Apache Commons Daemon"
  s.description = "Trinidad init service scripts on Apache Commons Daemon and JRuby-jsvc, compatible with Unix and Windows services"

  ## List the primary authors. If there are a bunch of authors, it's probably
  ## better to set the email to an email list or something. If you don't have
  ## a custom homepage, consider using your GitHub URL or the like.
  s.authors  = ["David Calavera"]
  s.email    = 'calavera@apache.org'
  s.homepage = 'http://github.com/calavera/trinidad_daemon'

  ## This gets added to the $LOAD_PATH so that 'lib/NAME.rb' can be required as
  ## require 'NAME.rb' or'/lib/NAME/file.rb' can be as require 'NAME/file.rb'
  s.require_paths = %w[lib]

  ## If your gem includes any executables, list them here.
  s.executables = ["trinidad_init_service"]
  s.default_executable = 'trinidad_daemon_install'

  ## Specify any RDoc options here. You'll want to add your README and
  ## LICENSE files to the extra_rdoc_files list.
  s.rdoc_options = ["--charset=UTF-8"]
  s.extra_rdoc_files = %w[README LICENSE]

  ## List your runtime dependencies here. Runtime dependencies are those
  ## that are needed for an end user to actually USE your code.
  s.add_dependency('trinidad', '>=1.2.2')

  s.add_development_dependency('rspec', '>= 2.7.1')
  s.add_development_dependency('mocha', '>= 0.10')
  
  ## Leave this section as-is. It will be automatically generated from the
  ## contents of your Git repository via the gemspec task. DO NOT REMOVE
  ## THE MANIFEST COMMENTS, they are used as delimiters by the task.
  # = MANIFEST =
  s.files = %w[
    History.txt
    LICENSE
    README
    Rakefile
    bin/trinidad_init_service
    init.d/trinidad.erb
    lib/trinidad_init_services.rb
    lib/trinidad_init_services/configuration.rb
    spec/spec_helper.rb
    spec/trinidad_init_services/configuration_spec.rb
    trinidad-libs/commons-daemon.jar
    trinidad-libs/jruby-jsvc.jar
    trinidad-libs/jsvc_darwin
    trinidad-libs/jsvc_linux
    trinidad-libs/prunsrv_amd64.exe
    trinidad-libs/prunsrv_ia64.exe
    trinidad_init_services.gemspec
  ]
  # = MANIFEST =

  ## Test files will be grabbed from the file list. Make sure the path glob
  ## matches what you actually use.
  ## s.test_files = s.files.select { |path| path =~ /^test\/test_.*\.rb/ }

s.post_install_message = <<TEXT

------------------------------------------------------------------------------------

Please now run:

  $ jruby -S trinidad_init_service

to complete the installation.

------------------------------------------------------------------------------------

TEXT
end
