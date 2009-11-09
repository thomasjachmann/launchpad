module Launchpad
  
  class Device
    
    # Initializes the launchpad
    # {
    #   :device_name  => Name of the MIDI device to use, optional, defaults to Launchpad
    #   :input        => true/false, whether to use MIDI input for user interaction, optional, defaults to true
    #   :output       => true/false, whether to use MIDI output for data display, optional, defaults to true
    # }
    def initialize(opts = nil)
      opts = {
        :device_name  => 'Launchpad',
        :input        => true,
        :output       => true
      }.merge(opts || {})
      
      Portmidi.start
      
      if opts[:input]
        input_device = Portmidi.input_devices.select {|device| device.name == opts[:device_name]}.first
        raise NoSuchDeviceError.new("input device #{opts[:device_name]} doesn't exist") if input_device.nil?
        @input = Portmidi::Input.new(input_device.device_id)
      end
      
      if opts[:output]
        output_device = Portmidi.output_devices.select {|device| device.name == opts[:device_name]}.first
        raise NoSuchDeviceError.new("output device #{opts[:device_name]} doesn't exist") if output_device.nil?
        @output = Portmidi::Output.new(output_device.device_id)
        reset
      end
    end
    
    # Reset the launchpad - all settings are reset and all LEDs are switched off
    def reset
      output(MidiCodes::CC, MidiCodes::NIL, MidiCodes::NIL)
    end
    
    # Light all LEDs (for testing purposes)
    # takes an optional parameter brightness (:off/:low/:medium/:high, defaults to :high)
    def light_all(brightness = :high)
      brightness = brightness(brightness)
      if brightness == 0
        reset
      else
        output(MidiCodes::CC, MidiCodes::NIL, MidiCodes::LIGHT_ALL + brightness)
      end
    end
    
    # Switches a single LED
    # * :type   => one of :grid, :up, :down, :left, :right, :session, :user1, :user2, :mixer, :scene1 - :scene8, optional, defaults to :grid, where :x and :y have to be specified
    # * :x      => x coordinate (0 based from top left, mandatory if :type is :grid)
    # * :y      => y coordinate (0 based from top left, mandatory if :type is :grid)
    # * :red    => brightness of red LED (0-3, optional, defaults to 0)
    # * :green  => brightness of red LED (0-3, optional, defaults to 0)
    # * :mode   => button behaviour (:normal, :flashing, :buffering, optional, defaults to :normal)
    def single(opts)
      output(code(opts), note(opts), velocity(opts))
    end
    
    # Switches all LEDs at once
    # velocities is an array of arrays, each containing a
    # color value calculated using the formula
    # color = 16 * green + red
    # with green and red each ranging from 0-3
    # first the grid, then the scene buttons (top to bottom), then the top control buttons (left to right), maximum 80 values
    def multi(*colors)
      colors = colors.flatten[0..79]
      colors += [0] * (80 - colors.size) if colors.size < 80
      output(MidiCodes::ON, 0, 0)
      colors.each_slice(2) do |c1, c2|
        output(MidiCodes::MULTI, velocity(c1), velocity(c2))
      end
    end
    
    # Switches LEDs marked as flashing on (when using custom timer for flashing)
    def flashing_on
      output(MidiCodes::CC, MidiCodes::NIL, MidiCodes::FLASH_ON)
    end

    # Switches LEDs marked as flashing off (when using custom timer for flashing)
    def flashing_off
      output(MidiCodes::CC, MidiCodes::NIL, MidiCodes::FLASH_OFF)
    end

    # Starts flashing LEDs marked as flashing automatically
    def flashing_auto
      output(MidiCodes::CC, MidiCodes::NIL, MidiCodes::FLASH_AUTO)
    end
    
    #   def start_buffering
    #     output(CC, 0x00, 0x31)
    #     @buffering = true
    #   end
    #   
    #   def flush_buffer(end_buffering = true)
    #     output(CC, 0x00, 0x34)
    #     if end_buffering
    #       output(CC, 0x00, 0x30)
    #       @buffering = false
    #     end
    #   end
    
    # Reads user actions (button presses/releases) that aren't handled yet
    # [
    #   {
    #     :timestamp  => integer indicating the time when the action occured
    #     :state      => true/false, whether the button has been pressed or released
    #     :type       => which button has been pressed, one of :grid, :up, :down, :left, :right, :session, :user1, :user2, :mixer, :scene1 - :scene8
    #     :x          => x coordinate (0-7), only set when :type is :grid
    #     :y          => y coordinate (0-7), only set when :type is :grid
    #   }, ...
    # ]
    def pending_user_actions
      Array(input).collect do |midi_message|
        (code, note, velocity) = midi_message[:message]
        data = {
          :timestamp  => midi_message[:timestamp],
          :state      => (velocity == 127)
        }
        data[:type] = case code
        when MidiCodes::ON
          case note
          when MidiCodes::BTN_SCENE1  then :scene1
          when MidiCodes::BTN_SCENE2  then :scene2
          when MidiCodes::BTN_SCENE3  then :scene3
          when MidiCodes::BTN_SCENE4  then :scene4
          when MidiCodes::BTN_SCENE5  then :scene5
          when MidiCodes::BTN_SCENE6  then :scene6
          when MidiCodes::BTN_SCENE7  then :scene7
          when MidiCodes::BTN_SCENE8  then :scene8
          else
            data[:x] = note % 16
            data[:y] = note / 16
            :grid
          end
        when MidiCodes::CC
          case note
          when MidiCodes::BTN_UP      then :up
          when MidiCodes::BTN_DOWN    then :down
          when MidiCodes::BTN_LEFT    then :left
          when MidiCodes::BTN_RIGHT   then :right
          when MidiCodes::BTN_SESSION then :session
          when MidiCodes::BTN_USER1   then :user1
          when MidiCodes::BTN_USER2   then :user2
          when MidiCodes::BTN_MIXER   then :mixer
          else
            # TODO raise error
          end
        end
        data
      end
    end
    
    private
    
    def input
      raise NoInputAllowedError if @input.nil?
      @input.read(16)
    end
    
    def output(*args)
      raise NoOutputAllowedError if @output.nil?
      @output.write([{:message => args, :timestamp => 0}])
      nil
    end
    
    def code(opts)
      case opts[:type]
      when :up, :down, :left, :right, :session, :user1, :user2, :mixer then MidiCodes::CC
      else MidiCodes::ON
      end
    end
    
    def note(opts)
      case opts[:type]
      when :up      then MidiCodes::BTN_UP
      when :down    then MidiCodes::BTN_DOWN
      when :left    then MidiCodes::BTN_LEFT
      when :right   then MidiCodes::BTN_RIGHT
      when :session then MidiCodes::BTN_SESSION
      when :user1   then MidiCodes::BTN_USER1
      when :user2   then MidiCodes::BTN_USER2
      when :mixer   then MidiCodes::BTN_MIXER
      when :scene1  then MidiCodes::BTN_SCENE1
      when :scene2  then MidiCodes::BTN_SCENE2
      when :scene3  then MidiCodes::BTN_SCENE3
      when :scene4  then MidiCodes::BTN_SCENE4
      when :scene5  then MidiCodes::BTN_SCENE5
      when :scene6  then MidiCodes::BTN_SCENE6
      when :scene7  then MidiCodes::BTN_SCENE7
      when :scene8  then MidiCodes::BTN_SCENE8
      else
        x = (opts[:x] || -1).to_i
        y = (opts[:y] || -1).to_i
        raise NoValidGridCoordinatesError.new('you need to specify valid coordinates (x/y, 0-7, from top left)') if x < 0 || x > 7 || y < 0 || y > 7
        y * 16 + x
      end
    end
    
    def velocity(opts)
      color = if opts.is_a?(Hash)
        red = brightness(opts[:red] || 0)
        green = brightness(opts[:green] || 0)
        16 * green + red
      else
        opts.to_i
      end
      flags = case opts[:mode]
      when :flashing  then  8
      when :buffering then  0
      else                  12
      end
      color + flags
    end
    
    def brightness(brightness)
      case brightness
      when 0, :off            then 0
      when 1, :low,     :lo   then 1
      when 2, :medium,  :med  then 2
      when 3, :high,    :hi   then 3
      else
        raise NoValidBrightnessError.new('you need to specify the brightness as 0/1/2/3, :off/:low/:medium/:high or :off/:lo/:hi')
      end
    end
    
  end
  
end
