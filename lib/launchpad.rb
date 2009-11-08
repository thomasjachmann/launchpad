require 'rubygems'
require 'portmidi'

class Launchpad
  
  class LaunchpadError < StandardError; end
  class NoInputAllowed < LaunchpadError; end
  class NoOutputAllowed < LaunchpadError; end
  class NoLocationError < LaunchpadError; end
  class CommunicationError < LaunchpadError
    attr_accessor :source
    def initialize(e)
      super(e.portmidi_error)
      self.source = e
    end
  end
  
  OFF = 0x80
  ON = 0x90
  CC = 0xB0
  
  def initialize(opts = nil)
    opts = {
      :device_name  => 'Launchpad',
      :input        => true,
      :output       => true
    }.merge(opts || {})
    Portmidi.start
    if opts[:input]
      input_device = Portmidi.input_devices.select {|device| device.name == opts[:device_name]}.first
      @input = Portmidi::Input.new(input_device.device_id)
    end
    if opts[:output]
      output_device = Portmidi.output_devices.select {|device| device.name == opts[:device_name]}.first
      @output = Portmidi::Output.new(output_device.device_id)
      reset
    end
    @buffering = false
  end
  
  def self.start(opts = nil, &block)
    opts ||= {}
    latency = (opts.delete(:latency) || 0.001).to_f
    launchpad = Launchpad.new(opts.merge({:input => true, :output => true}))
    loop do
      messages = launchpad.input
      if messages
        messages.each do |message|
          message = parse_message(message)
          if message[:code] == ON
            block.call(launchpad, message[:x], message[:y], message[:state])
          end
        end
      end
      sleep latency
    end
  rescue Portmidi::DeviceError => e
    raise CommunicationError.new(e)
  ensure
    launchpad.reset if launchpad
  end
  
  def light_all(brightness = 3)
    output(CC, 0x00, 124 + brightness)
  end
  
  def start_buffering
    output(CC, 0x00, 0x31)
    @buffering = true
  end
  
  def flush_buffer(end_buffering = true)
    output(CC, 0x00, 0x34)
    if end_buffering
      output(CC, 0x00, 0x30)
      @buffering = false
    end
  end
  
  def reset
    output(CC, 0x00, 0x00)
  end
  
  def single(opts)
    code = opts[:code] || ON
    location = location(opts)
    velocity = velocity(opts)
    output(code, location, velocity)
  end
  
  def multi(*velocities)
    output(CC, 0x01, 0x00)
    output(0x92, *velocities)
  end
  
  def custom_flashing_on
    output(CC, 0x00, 0x20)
  end
  
  def custom_flashing_off
    output(CC, 0x00, 0x21)
  end
  
  def start_auto_flashing
    output(CC, 0x00, 0x28)
  end
  
  alias_method :stop_auto_flashing, :custom_flashing_on
  
  def coordinates(location)
    [location % 16, location / 16]
  end
  
  def input
    raise NoInputAllowed if @input.nil?
    @input.read(16)
  end
  
  def output(*args)
    raise NoOutputAllowed if @output.nil?
    @output.write([{:message => args, :timestamp => 0}])
  end
  
  private
  
  def self.parse_message(message)
    message = message[:message]
    {
      :code   => message[0],
      :x      => message[1] % 16,
      :y      => message[1] / 16,
      :state  => message[2] == 127
    }
  end
  
  def location(opts)
    raise NoLocationError.new('you need to specify a location (x/y, 0 based from top left)') if (y = opts[:y]).nil? || (x = opts[:x]).nil?
    y * 16 + x
  end
  
  def velocity(opts)
    red = (opts[:red] || 0).to_i
    green = (opts[:green] || 0).to_i
    flags = case opts[:mode]
    when :flashing  then  8
    when :buffering then  0
    else                  12
    end
    (16 * (green)) + red + flags
  end
  
end
