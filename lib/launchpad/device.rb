require 'portmidi'

require 'launchpad/errors'
require 'launchpad/logging'
require 'launchpad/midi_codes'
require 'launchpad/version'

module Launchpad
  
  # This class is used to exchange data with the launchpad.
  # It provides methods to light LEDs and to get information about button presses/releases.
  # 
  # Example:
  # 
  #   require 'launchpad/device'
  #   
  #   device = Launchpad::Device.new
  #   device.test_leds
  #   sleep 1
  #   device.reset
  #   sleep 1
  #   device.change :grid, :x => 4, :y => 4, :red => :high, :green => :low
  class Device
    
    include Logging
    include MidiCodes
    
    CODE_NOTE_TO_DATA_TYPE = {
      [Status::ON, SceneButton::SCENE1]     => :scene1,
      [Status::ON, SceneButton::SCENE2]     => :scene2,
      [Status::ON, SceneButton::SCENE3]     => :scene3,
      [Status::ON, SceneButton::SCENE4]     => :scene4,
      [Status::ON, SceneButton::SCENE5]     => :scene5,
      [Status::ON, SceneButton::SCENE6]     => :scene6,
      [Status::ON, SceneButton::SCENE7]     => :scene7,
      [Status::ON, SceneButton::SCENE8]     => :scene8,
      [Status::CC, ControlButton::UP]       => :up,
      [Status::CC, ControlButton::DOWN]     => :down,
      [Status::CC, ControlButton::LEFT]     => :left,
      [Status::CC, ControlButton::RIGHT]    => :right,
      [Status::CC, ControlButton::SESSION]  => :session,
      [Status::CC, ControlButton::USER1]    => :user1,
      [Status::CC, ControlButton::USER2]    => :user2,
      [Status::CC, ControlButton::MIXER]    => :mixer
    }.freeze

    TYPE_TO_NOTE = {
      :up       => ControlButton::UP,
      :down     => ControlButton::DOWN,
      :left     => ControlButton::LEFT,
      :right    => ControlButton::RIGHT,
      :session  => ControlButton::SESSION,
      :user1    => ControlButton::USER1,
      :user2    => ControlButton::USER2,
      :mixer    => ControlButton::MIXER,
      :scene1   => SceneButton::SCENE1,
      :scene2   => SceneButton::SCENE2,
      :scene3   => SceneButton::SCENE3,
      :scene4   => SceneButton::SCENE4,
      :scene5   => SceneButton::SCENE5,
      :scene6   => SceneButton::SCENE6,
      :scene7   => SceneButton::SCENE7,
      :scene8   => SceneButton::SCENE8
    }.freeze

    # Initializes the launchpad device. When output capabilities are requested,
    # the launchpad will be reset.
    # 
    # Optional options hash:
    # 
    # [<tt>:input</tt>]             whether to use MIDI input for user interaction,
    #                               <tt>true/false</tt>, optional, defaults to +true+
    # [<tt>:output</tt>]            whether to use MIDI output for data display,
    #                               <tt>true/false</tt>, optional, defaults to +true+
    # [<tt>:input_device_id</tt>]   ID of the MIDI input device to use,
    #                               optional, <tt>:device_name</tt> will be used if omitted
    # [<tt>:output_device_id</tt>]  ID of the MIDI output device to use,
    #                               optional, <tt>:device_name</tt> will be used if omitted
    # [<tt>:device_name</tt>]       Name of the MIDI device to use,
    #                               optional, defaults to "Launchpad"
    # [<tt>:logger</tt>]            [Logger] to be used by this device instance, can be changed afterwards
    # 
    # Errors raised:
    # 
    # [Launchpad::NoSuchDeviceError] when device with ID or name specified does not exist
    # [Launchpad::DeviceBusyError] when device with ID or name specified is busy
    def initialize(opts = nil)
      opts = {
        :input        => true,
        :output       => true
      }.merge(opts || {})
      
      self.logger = opts[:logger]
      logger.debug "initializing Launchpad::Device##{object_id} with #{opts.inspect}"

      Portmidi.start
      
      @input = create_device!(Portmidi.input_devices, Portmidi::Input,
        :id => opts[:input_device_id],
        :name => opts[:device_name]
      ) if opts[:input]
      @output = create_device!(Portmidi.output_devices, Portmidi::Output,
        :id => opts[:output_device_id],
        :name => opts[:device_name]
      ) if opts[:output]

      reset if output_enabled?
    end
    
    # Closes the device - nothing can be done with the device afterwards.
    def close
      logger.debug "closing Launchpad::Device##{object_id}"
      @input.close unless @input.nil?
      @input = nil
      @output.close unless @output.nil?
      @output = nil
    end
    
    # Determines whether this device has been closed.
    def closed?
      !(input_enabled? || output_enabled?)
    end
    
    # Determines whether this device can be used to read input.
    def input_enabled?
      !@input.nil?
    end
    
    # Determines whether this device can be used to output data.
    def output_enabled?
      !@output.nil?
    end
    
    # Resets the launchpad - all settings are reset and all LEDs are switched off.
    # 
    # Errors raised:
    # 
    # [Launchpad::NoOutputAllowedError] when output is not enabled
    def reset
      output(Status::CC, Status::NIL, Status::NIL)
    end
    
    # Lights all LEDs (for testing purposes).
    # 
    # Parameters (see Launchpad for values):
    # 
    # [+brightness+] brightness of both LEDs for all buttons
    # 
    # Errors raised:
    # 
    # [Launchpad::NoOutputAllowedError] when output is not enabled
    def test_leds(brightness = :high)
      brightness = brightness(brightness)
      if brightness == 0
        reset
      else
        output(Status::CC, Status::NIL, Velocity::TEST_LEDS + brightness)
      end
    end
    
    # Changes a single LED.
    # 
    # Parameters (see Launchpad for values):
    # 
    # [+type+] type of the button to change
    # 
    # Optional options hash (see Launchpad for values):
    # 
    # [<tt>:x</tt>]     x coordinate
    # [<tt>:y</tt>]     y coordinate
    # [<tt>:red</tt>]   brightness of red LED
    # [<tt>:green</tt>] brightness of green LED
    # [<tt>:mode</tt>]  button mode, defaults to <tt>:normal</tt>, one of:
    #                   [<tt>:normal/tt>]     updates the LED for all circumstances (the new value will be written to both buffers)
    #                   [<tt>:flashing/tt>]   updates the LED for flashing (the new value will be written to buffer 0 while the LED will be off in buffer 1, see buffering_mode)
    #                   [<tt>:buffering/tt>]  updates the LED for the current update_buffer only
    # 
    # Errors raised:
    # 
    # [Launchpad::NoValidGridCoordinatesError] when coordinates aren't within the valid range
    # [Launchpad::NoValidBrightnessError] when brightness values aren't within the valid range
    # [Launchpad::NoOutputAllowedError] when output is not enabled
    def change(type, opts = nil)
      opts ||= {}
      status = %w(up down left right session user1 user2 mixer).include?(type.to_s) ? Status::CC : Status::ON
      output(status, note(type, opts), velocity(opts))
    end
    
    # Changes all LEDs in batch mode.
    # 
    # Parameters (see Launchpad for values):
    # 
    # [+colors] an array of colors, each either being an integer or a Hash
    #           * integer: calculated using the formula
    #             <tt>color = 16 * green + red</tt>
    #           * Hash:
    #             [<tt>:red</tt>]   brightness of red LED
    #             [<tt>:green</tt>] brightness of green LED
    #             [<tt>:mode</tt>]  button mode, defaults to <tt>:normal</tt>, one of:
    #                               [<tt>:normal/tt>]     updates the LEDs for all circumstances (the new value will be written to both buffers)
    #                               [<tt>:flashing/tt>]   updates the LEDs for flashing (the new values will be written to buffer 0 while the LEDs will be off in buffer 1, see buffering_mode)
    #                               [<tt>:buffering/tt>]  updates the LEDs for the current update_buffer only
    #           the array consists of 64 colors for the grid buttons,
    #           8 colors for the scene buttons (top to bottom)
    #           and 8 colors for the top control buttons (left to right),
    #           maximum 80 values - excessive values will be ignored,
    #           missing values will be filled with 0
    # 
    # Errors raised:
    # 
    # [Launchpad::NoValidBrightnessError] when brightness values aren't within the valid range
    # [Launchpad::NoOutputAllowedError] when output is not enabled
    def change_all(*colors)
      # ensure that colors is at least and most 80 elements long
      colors = colors.flatten[0..79]
      colors += [0] * (80 - colors.size) if colors.size < 80
      # send normal MIDI message to reset rapid LED change pointer
      # in this case, set mapping mode to x-y layout (the default)
      output(Status::CC, Status::NIL, GridLayout::XY)
      # send colors in slices of 2
      messages = []
      colors.each_slice(2) do |c1, c2|
        messages << message(Status::MULTI, velocity(c1), velocity(c2))
      end
      output_messages(messages)
    end
    
    # Switches LEDs marked as flashing on when using custom timer for flashing.
    # 
    # Errors raised:
    # 
    # [Launchpad::NoOutputAllowedError] when output is not enabled
    def flashing_on
      buffering_mode(:display_buffer => 0)
    end
    
    # Switches LEDs marked as flashing off when using custom timer for flashing.
    # 
    # Errors raised:
    # 
    # [Launchpad::NoOutputAllowedError] when output is not enabled
    def flashing_off
      buffering_mode(:display_buffer => 1)
    end
    
    # Starts flashing LEDs marked as flashing automatically.
    # Stop flashing by calling flashing_on or flashing_off.
    # 
    # Errors raised:
    # 
    # [Launchpad::NoOutputAllowedError] when output is not enabled
    def flashing_auto
      buffering_mode(:flashing => true)
    end
    
    # Controls the two buffers.
    # 
    # Optional options hash:
    # 
    # [<tt>:display_buffer</tt>]  which buffer to use for display, defaults to +0+
    # [<tt>:update_buffer</tt>]   which buffer to use for updates when <tt>:mode</tt> is set to <tt>:buffering</tt>, defaults to +0+ (see change)
    # [<tt>:copy</tt>]            whether to copy the LEDs states from the new display_buffer over to the new update_buffer, <tt>true/false</tt>, defaults to <tt>false</tt>
    # [<tt>:flashing</tt>]        whether to start flashing by automatically switching between the two buffers for display, <tt>true/false</tt>, defaults to <tt>false</tt>
    # 
    # Errors raised:
    # 
    # [Launchpad::NoOutputAllowedError] when output is not enabled
    def buffering_mode(opts = nil)
      opts = {
        :display_buffer => 0,
        :update_buffer => 0,
        :copy => false,
        :flashing => false
      }.merge(opts || {})
      data = opts[:display_buffer] + 4 * opts[:update_buffer] + 32
      data += 16 if opts[:copy]
      data += 8 if opts[:flashing]
      output(Status::CC, Status::NIL, data)
    end
    
    # Reads user actions (button presses/releases) that haven't been handled yet.
    # This is non-blocking, so when nothing happend yet you'll get an empty array.
    # 
    # Returns:
    # 
    # an array of hashes with (see Launchpad for values):
    # 
    # [<tt>:timestamp</tt>] integer indicating the time when the action occured
    # [<tt>:state</tt>]     state of the button after action
    # [<tt>:type</tt>]      type of the button
    # [<tt>:x</tt>]         x coordinate
    # [<tt>:y</tt>]         y coordinate
    # 
    # Errors raised:
    # 
    # [Launchpad::NoInputAllowedError] when input is not enabled
    def read_pending_actions
      Array(input).collect do |midi_message|
        (code, note, velocity) = midi_message[:message]
        data = {
          :timestamp  => midi_message[:timestamp],
          :state      => (velocity == 127 ? :down : :up)
        }
        data[:type] = CODE_NOTE_TO_DATA_TYPE[[code, note]] || :grid
        if data[:type] == :grid
          data[:x] = note % 16
          data[:y] = note / 16
        end
        data
      end
    end
    
    private
    
    # Creates input/output devices.
    # 
    # Parameters:
    # 
    # [+devices+]     array of portmidi devices
    # [+device_type]  class to instantiate (<tt>Portmidi::Input/Portmidi::Output</tt>)
    # 
    # Options hash:
    # 
    # [<tt>:id</tt>]    id of the MIDI device to use
    # [<tt>:name</tt>]  name of the MIDI device to use,
    #                   only used when <tt>:id</tt> is not specified,
    #                   defaults to "Launchpad"
    # 
    # Returns:
    # 
    # newly created device
    # 
    # Errors raised:
    # 
    # [Launchpad::NoSuchDeviceError] when device with ID or name specified does not exist
    # [Launchpad::DeviceBusyError] when device with ID or name specified is busy
    def create_device!(devices, device_type, opts)
      logger.debug "creating #{device_type} with #{opts.inspect}, choosing from portmidi devices #{devices.inspect}"
      id = opts[:id]
      if id.nil?
        name = opts[:name] || /Launchpad.*/
        device = devices.select {|device| device.name =~ name}.first
        id = device.device_id unless device.nil?
      end
      if id.nil?
        message = "MIDI device #{opts[:id] || opts[:name]} doesn't exist"
        logger.fatal message
        raise NoSuchDeviceError.new(message)
      end
      device_type.new(id)
    rescue RuntimeError => e
      logger.fatal "error creating #{device_type}: #{e.inspect}"
      raise DeviceBusyError.new(e)
    end
    
    # Reads input from the MIDI device.
    # 
    # Returns:
    # 
    # an array of hashes with:
    # 
    # [<tt>:message</tt>]   an array of
    #                       MIDI status code,
    #                       MIDI data 1 (note),
    #                       MIDI data 2 (velocity)
    #                       and a fourth value
    # [<tt>:timestamp</tt>] integer indicating the time when the MIDI message was created
    # 
    # Errors raised:
    # 
    # [Launchpad::NoInputAllowedError] when output is not enabled
    def input
      if @input.nil?
        logger.error "trying to read from device that's not been initialized for input"
        raise NoInputAllowedError
      end
      @input.read(16)
    end
    
    # Writes data to the MIDI device.
    # 
    # Parameters:
    # 
    # [+status+]  MIDI status code
    # [+data1+]   MIDI data 1 (note)
    # [+data2+]   MIDI data 2 (velocity)
    # 
    # Errors raised:
    # 
    # [Launchpad::NoOutputAllowedError] when output is not enabled
    def output(status, data1, data2)
      output_messages([message(status, data1, data2)])
    end
    
    # Writes several messages to the MIDI device.
    # 
    # Parameters:
    # 
    # [+messages+]  an array of hashes (usually created with message) with:
    #               [<tt>:message</tt>]   an array of
    #                                     MIDI status code,
    #                                     MIDI data 1 (note),
    #                                     MIDI data 2 (velocity)
    #               [<tt>:timestamp</tt>] integer indicating the time when the MIDI message was created
    def output_messages(messages)
      if @output.nil?
        logger.error "trying to write to device that's not been initialized for output"
        raise NoOutputAllowedError
      end
      logger.debug "writing messages to launchpad:\n  #{messages.join("\n  ")}" if logger.debug?
      @output.write(messages)
      nil
    end
    
    # Calculates the MIDI data 1 value (note) for a button.
    # 
    # Parameters (see Launchpad for values):
    # 
    # [+type+] type of the button
    # 
    # Options hash:
    # 
    # [<tt>:x</tt>]     x coordinate
    # [<tt>:y</tt>]     y coordinate
    # 
    # Returns:
    # 
    # integer to be used for MIDI data 1
    # 
    # Errors raised:
    # 
    # [Launchpad::NoValidGridCoordinatesError] when coordinates aren't within the valid range
    def note(type, opts)
      note = TYPE_TO_NOTE[type]
      if note.nil?
        x = (opts[:x] || -1).to_i
        y = (opts[:y] || -1).to_i
        if x < 0 || x > 7 || y < 0 || y > 7
          logger.error "wrong coordinates specified: x=#{x}, y=#{y}"
          raise NoValidGridCoordinatesError.new("you need to specify valid coordinates (x/y, 0-7, from top left), you specified: x=#{x}, y=#{y}")
        end
        note = y * 16 + x
      end
      note
    end
    
    # Calculates the MIDI data 2 value (velocity) for given brightness and mode values.
    # 
    # Options hash:
    # 
    # [<tt>:red</tt>]   brightness of red LED
    # [<tt>:green</tt>] brightness of green LED
    # [<tt>:mode</tt>]  button mode, defaults to <tt>:normal</tt>, one of:
    #                   [<tt>:normal/tt>]     updates the LED for all circumstances (the new value will be written to both buffers)
    #                   [<tt>:flashing/tt>]   updates the LED for flashing (the new value will be written to buffer 0 while in buffer 1, the value will be :off, see )
    #                   [<tt>:buffering/tt>]  updates the LED for the current update_buffer only
    # 
    # Returns:
    # 
    # integer to be used for MIDI data 2
    # 
    # Errors raised:
    # 
    # [Launchpad::NoValidBrightnessError] when brightness values aren't within the valid range
    def velocity(opts)
      if opts.is_a?(Hash)
        red = brightness(opts[:red] || 0)
        green = brightness(opts[:green] || 0)
        color = 16 * green + red
        flags = case opts[:mode]
                when :flashing  then  8
                when :buffering then  0
                else                  12
                end
        color + flags
      else
        opts.to_i + 12
      end
    end
    
    # Calculates the integer brightness for given brightness values.
    # 
    # Parameters (see Launchpad for values):
    # 
    # [+brightness+] brightness
    # 
    # Errors raised:
    # 
    # [Launchpad::NoValidBrightnessError] when brightness values aren't within the valid range
    def brightness(brightness)
      case brightness
      when 0, :off            then 0
      when 1, :low,     :lo   then 1
      when 2, :medium,  :med  then 2
      when 3, :high,    :hi   then 3
      else
        logger.error "wrong brightness specified: #{brightness}"
        raise NoValidBrightnessError.new("you need to specify the brightness as 0/1/2/3, :off/:low/:medium/:high or :off/:lo/:hi, you specified: #{brightness}")
      end
    end
    
    # Creates a MIDI message.
    # 
    # Parameters:
    # 
    # [+status+]  MIDI status code
    # [+data1+]   MIDI data 1 (note)
    # [+data2+]   MIDI data 2 (velocity)
    # 
    # Returns:
    # 
    # an array with:
    # 
    # [<tt>:message</tt>]   an array of
    #                       MIDI status code,
    #                       MIDI data 1 (note),
    #                       MIDI data 2 (velocity)
    # [<tt>:timestamp</tt>] integer indicating the time when the MIDI message was created, in this case 0
    def message(status, data1, data2)
      {:message => [status, data1, data2], :timestamp => 0}
    end
    
  end
  
end
