require 'launchpad/device'
require 'launchpad/logging'

module Launchpad
  
  # This class provides advanced interaction features.
  # 
  # Example:
  # 
  #   require 'launchpad'
  #   
  #   interaction = Launchpad::Interaction.new
  #   interaction.response_to(:grid, :down) do |interaction, action|
  #     interaction.device.change(:grid, action.merge(:red => :high))
  #   end
  #   interaction.response_to(:mixer, :down) do |interaction, action|
  #     interaction.stop
  #   end
  #   
  #   interaction.start
  class Interaction

    include Logging
    
    # Returns the Launchpad::Device the Launchpad::Interaction acts on.
    attr_reader :device
    
    # Returns whether the Launchpad::Interaction is active or not.
    attr_reader :active
    
    # Initializes the interaction.
    # 
    # Optional options hash:
    # 
    # [<tt>:device</tt>]            Launchpad::Device to act on,
    #                               optional, <tt>:input_device_id/:output_device_id</tt> will be used if omitted
    # [<tt>:input_device_id</tt>]   ID of the MIDI input device to use,
    #                               optional, <tt>:device_name</tt> will be used if omitted
    # [<tt>:output_device_id</tt>]  ID of the MIDI output device to use,
    #                               optional, <tt>:device_name</tt> will be used if omitted
    # [<tt>:device_name</tt>]       Name of the MIDI device to use,
    #                               optional, defaults to "Launchpad"
    # [<tt>:latency</tt>]           delay (in s, fractions allowed) between MIDI pulls,
    #                               optional, defaults to 0.001 (1ms)
    # [<tt>:logger</tt>]            [Logger] to be used by this interaction instance, can be changed afterwards
    # 
    # Errors raised:
    # 
    # [Launchpad::NoSuchDeviceError] when device with ID or name specified does not exist
    # [Launchpad::DeviceBusyError] when device with ID or name specified is busy
    def initialize(opts = nil)
      opts ||= {}

      self.logger = opts[:logger]
      logger.debug "initializing Launchpad::Interaction##{object_id} with #{opts.inspect}"

      @device = opts[:device]
      @device ||= Device.new(opts.merge(
        :input => true,
        :output => true,
        :logger => opts[:logger]
      ))
      @latency = (opts[:latency] || 0.001).to_f.abs
      @active = false

      @action_threads = ThreadGroup.new
    end

    # Sets the logger to be used by the current instance and the device.
    # 
    # [+logger+]  the [Logger] instance
    def logger=(logger)
      @logger = logger
      @device.logger = logger if @device
    end

    # Closes the interaction's device - nothing can be done with the interaction/device afterwards.
    # 
    # Errors raised:
    # 
    # [Launchpad::NoInputAllowedError] when input is not enabled on the interaction's device
    # [Launchpad::CommunicationError] when anything unexpected happens while communicating with the    
    def close
      logger.debug "closing Launchpad::Interaction##{object_id}"
      stop
      @device.close
    end
    
    # Determines whether this interaction's device has been closed.
    def closed?
      @device.closed?
    end
    
    # Starts interacting with the launchpad. Resets the device when
    # the interaction was properly stopped via stop or close.
    # 
    # Optional options hash:
    # 
    # [<tt>:detached</tt>]  <tt>true/false</tt>,
    #                       whether to detach the interaction, method is blocking when +false+,
    #                       optional, defaults to +false+
    # 
    # Errors raised:
    # 
    # [Launchpad::NoInputAllowedError] when input is not enabled on the interaction's device
    # [Launchpad::NoOutputAllowedError] when output is not enabled on the interaction's device
    # [Launchpad::CommunicationError] when anything unexpected happens while communicating with the launchpad
    def start(opts = nil)
      logger.debug "starting Launchpad::Interaction##{object_id}"

      opts = {
        :detached => false
      }.merge(opts || {})

      @active = true

      @reader_thread ||= Thread.new do
        begin
          while @active do
            @device.read_pending_actions.each do |action|
              action_thread = Thread.new(action) do |action|
                respond_to_action(action)
              end
              @action_threads.add(action_thread)
            end
            sleep @latency# if @latency > 0.0
          end
        rescue Portmidi::DeviceError => e
          logger.fatal "could not read from device, stopping to read actions"
          raise CommunicationError.new(e)
        rescue Exception => e
          logger.fatal "error causing action reading to stop: #{e.inspect}"
          raise e
        ensure
          @device.reset
        end
      end
      @reader_thread.join unless opts[:detached]
    end
    
    # Stops interacting with the launchpad.
    # 
    # Errors raised:
    # 
    # [Launchpad::NoInputAllowedError] when input is not enabled on the interaction's device
    # [Launchpad::CommunicationError] when anything unexpected happens while communicating with the    
    def stop
      logger.debug "stopping Launchpad::Interaction##{object_id}"
      @active = false
      if @reader_thread
        # run (resume from sleep) and wait for @reader_thread to end
        @reader_thread.run if @reader_thread.alive?
        @reader_thread.join
        @reader_thread = nil
      end
    ensure
      @action_threads.list.each do |thread|
        begin
          thread.kill
          thread.join
        rescue Exception => e
          logger.error "error when killing action thread: #{e.inspect}"
        end
      end
      nil
    end
    
    # Registers a response to one or more actions.
    # 
    # Parameters (see Launchpad for values):
    # 
    # [+types+] one or an array of button types to respond to,
    #           additional value <tt>:all</tt> for all buttons
    # [+state+] button state to respond to,
    #           additional value <tt>:both</tt>
    # 
    # Optional options hash:
    # 
    # [<tt>:exclusive</tt>] <tt>true/false</tt>,
    #                       whether to deregister all other responses to the specified actions,
    #                       optional, defaults to +false+
    # [<tt>:x</tt>]         x coordinate(s), can contain arrays and ranges, when specified
    #                       without y coordinate, it's interpreted as a whole column
    # [<tt>:y</tt>]         y coordinate(s), can contain arrays and ranges, when specified
    #                       without x coordinate, it's interpreted as a whole row
    # 
    # Takes a block which will be called when an action matching the parameters occurs.
    # 
    # Block parameters:
    # 
    # [+interaction+] the interaction object that received the action
    # [+action+]      the action received from Launchpad::Device.read_pending_actions
    def response_to(types = :all, state = :both, opts = nil, &block)
      logger.debug "setting response to #{types.inspect} for state #{state.inspect} with #{opts.inspect}"
      types = Array(types)
      opts ||= {}
      no_response_to(types, state) if opts[:exclusive] == true
      Array(state == :both ? %w(down up) : state).each do |state|
        types.each do |type|
          combined_types(type, opts).each do |combined_type|
            responses[combined_type][state.to_sym] << block
          end
        end
      end
      nil
    end
    
    # Deregisters all responses to one or more actions.
    # 
    # Parameters (see Launchpad for values):
    # 
    # [+types+] one or an array of button types to respond to,
    #           additional value <tt>:all</tt> for actions on all buttons
    #           (but not meaning "all responses"),
    #           optional, defaults to +nil+, meaning "all responses"
    # [+state+] button state to respond to,
    #           additional value <tt>:both</tt>
    # 
    # Optional options hash:
    # 
    # [<tt>:x</tt>] x coordinate(s), can contain arrays and ranges, when specified
    #               without y coordinate, it's interpreted as a whole column
    # [<tt>:y</tt>] y coordinate(s), can contain arrays and ranges, when specified
    #               without x coordinate, it's interpreted as a whole row
    def no_response_to(types = nil, state = :both, opts = nil)
      logger.debug "removing response to #{types.inspect} for state #{state.inspect}"
      types = Array(types)
      Array(state == :both ? %w(down up) : state).each do |state|
        types.each do |type|
          combined_types(type, opts).each do |combined_type|
            responses[combined_type][state.to_sym].clear
          end
        end
      end
      nil
    end
    
    # Responds to an action by executing all matching responses, effectively simulating
    # a button press/release.
    # 
    # Parameters (see Launchpad for values):
    # 
    # [+type+]  type of the button to trigger
    # [+state+] state of the button
    # 
    # Optional options hash (see Launchpad for values):
    # 
    # [<tt>:x</tt>]     x coordinate
    # [<tt>:y</tt>]     y coordinate
    def respond_to(type, state, opts = nil)
      respond_to_action((opts || {}).merge(:type => type, :state => state))
    end
    
    private
    
    # Returns the hash storing all responses. Keys are button types, values are
    # hashes themselves, keys are <tt>:down/:up</tt>, values are arrays of responses.
    def responses
      @responses ||= Hash.new {|hash, key| hash[key] = {:down => [], :up => []}}
    end

    # Returns an array of grid positions for a range.
    # 
    # Parameters:
    # 
    # [+range+] the range definitions, can be
    #           * a Fixnum
    #           * a Range
    #           * an Array of Fixnum, Range or Array objects
    def grid_range(range)
      return nil if range.nil?
      Array(range).flatten.map do |pos|
        pos.respond_to?(:to_a) ? pos.to_a : pos
      end.flatten.uniq
    end

    # Returns a list of combined types for the type and opts specified. Combined
    # types are just the type, except for grid, where the opts are interpreted
    # and all combinations of x and y coordinates are added as a position suffix.
    # 
    # Example:
    # 
    # combined_types(:grid, :x => 1..2, y => 2) => [:grid12, :grid22]
    # 
    # Parameters (see Launchpad for values):
    # 
    # [+type+]  type of the button
    # 
    # Optional options hash:
    # 
    # [<tt>:x</tt>] x coordinate(s), can contain arrays and ranges, when specified
    #               without y coordinate, it's interpreted as a whole column
    # [<tt>:y</tt>] y coordinate(s), can contain arrays and ranges, when specified
    #               without x coordinate, it's interpreted as a whole row
    def combined_types(type, opts = nil)
      if type.to_sym == :grid && opts
        x = grid_range(opts[:x])
        y = grid_range(opts[:y])
        return [:grid] if x.nil? && y.nil?  # whole grid
        x ||= ['-']                         # whole row
        y ||= ['-']                         # whole column
        x.product(y).map {|x, y| :"grid#{x}#{y}"}
      else
        [type.to_sym]
      end
    end
    
    # Reponds to an action by executing all matching responses.
    # 
    # Parameters:
    # 
    # [+action+]  hash containing an action from Launchpad::Device.read_pending_actions
    def respond_to_action(action)
      type = action[:type].to_sym
      state = action[:state].to_sym
      actions = []
      if type == :grid
        actions += responses[:"grid#{action[:x]}#{action[:y]}"][state]
        actions += responses[:"grid#{action[:x]}-"][state]
        actions += responses[:"grid-#{action[:y]}"][state]
      end
      actions += responses[type][state]
      actions += responses[:all][state]
      actions.compact.each {|block| block.call(self, action)}
      nil
    rescue Exception => e
      logger.error "error when responding to action #{action.inspect}: #{e.inspect}"
      raise e
    end
    
  end
  
end