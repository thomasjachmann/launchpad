require 'rubygems'
require 'rake'

require File.join(File.dirname(__FILE__), 'lib', 'launchpad', 'version')

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    gem.name = 'launchpad'
    gem.summary = 'A gem for accessing novation\'s launchpad programmatically and easily.'
    gem.description = 'This gem provides an interface to access novation\'s launchpad programmatically. LEDs can be lighted and button presses can be evaluated using launchpad\'s MIDI input/output.'
    gem.email = 'tom.j@gmx.net'
    gem.homepage = 'http://github.com/thomasjachmann/launchpad'
    gem.version = Launchpad::VERSION
    gem.authors = ['Thomas Jachmann']
    gem.add_dependency('portmidi')
    gem.add_development_dependency('thoughtbot-shoulda', '>= 0')
    gem.add_development_dependency('mocha')
    # gem is a Gem::Specification... see http://www.rubygems.org/read/chapter/20 for additional settings
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  puts 'Jeweler (or a dependency) not available. Install it with: sudo gem install jeweler'
end

require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.pattern = 'test/**/test_*.rb'
  test.verbose = true
end

begin
  require 'rcov/rcovtask'
  Rcov::RcovTask.new do |test|
    test.libs << 'test'
    test.pattern = 'test/**/test_*.rb'
    test.verbose = true
  end
rescue LoadError
  task :rcov do
    abort 'RCov is not available. In order to run rcov, you must: sudo gem install spicycode-rcov'
  end
end

task :test => :check_dependencies

task :default => :test

require 'rake/rdoctask'
Rake::RDocTask.new do |rdoc|
  version = File.exist?('VERSION') ? File.read('VERSION') : ""

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "launchpad #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end
