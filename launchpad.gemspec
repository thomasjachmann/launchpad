# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "launchpad/version"

Gem::Specification.new do |s|
  s.name        = "launchpad"
  s.version     = Launchpad::VERSION
  s.authors     = ["Thomas Jachmann"]
  s.email       = ["self@thomasjachmann.com"]
  s.homepage    = "https://github.com/thomasjachmann/launchpad"
  s.summary     = %q{A gem for accessing novation's launchpad programmatically and easily.}
  s.description = %q{This gem provides an interface to access novation's launchpad programmatically. LEDs can be lighted and button presses can be evaluated using launchpad's MIDI input/output.}

  s.rubyforge_project = "launchpad"

  s.add_dependency "portmidi", ">= 0.0.6"
  s.add_dependency "ffi"
  s.add_development_dependency "shoulda"
  s.add_development_dependency "mocha"
  s.add_development_dependency "redgreen"

  # s.has_rdoc = true

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
end
