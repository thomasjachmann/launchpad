require 'rubygems'
require 'bundler/setup'

require 'test/unit'
require 'shoulda'
require 'mocha'
require 'redgreen' if ENV['TM_FILENAME'].nil?

require 'launchpad'

class Test::Unit::TestCase
end

# mock Portmidi for tests
module Portmidi
  
  class Input
    attr_accessor :device_id
    def initialize(device_id)
      self.device_id = device_id
    end
    def read(*args); nil; end
    def close; nil; end
  end
  
  class Output
    attr_accessor :device_id
    def initialize(device_id)
      self.device_id = device_id
    end
    def write(*args); nil; end
    def close; nil; end
  end
  
  def self.input_devices; mock_devices; end
  def self.output_devices; mock_devices; end
  def self.start; end
  
end

def mock_devices(opts = {})
  [Portmidi::Device.new(opts[:id] || 1, 0, 0, opts[:name] || 'Launchpad')]
end
