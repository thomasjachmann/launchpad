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
      @device = opts[:device]
      @device ||= Device.new(opts.merge(
        :input => true,
        :output => true,
        :logger => opts[:logger]
      ))
      @latency = (opts[:latency] || 0.001).to_f.abs
      @active = false
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
      opts = {
        :detached => false
      }.merge(opts || {})
      @active = true
      # TODO rescue and reraise reader exceptions onto the main thread
      @reader_thread ||= Thread.new do
        begin
          while @active do
            # TODO rescue and reraise action exceptions onto the main thread
            @device.read_pending_actions.each {|action| Thread.new {respond_to_action(action)}}
            sleep @latency unless @latency <= 0
          end
        rescue Portmidi::DeviceError => e
          raise CommunicationError.new(e)
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
      @active = false
      if @reader_thread
        # run (resume from sleep) and wait for @reader_thread to end
        @reader_thread.run if @reader_thread.alive?
        @reader_thread.join
        @reader_thread = nil
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
    # 
    # Takes a block which will be called when an action matching the parameters occurs.
    # 
    # Block parameters:
    # 
    # [+interaction+] the interaction object that received the action
    # [+action+]      the action received from Launchpad::Device.read_pending_actions
    def response_to(types = :all, state = :both, opts = nil, &block)
      types = Array(types)
      opts ||= {}
      no_response_to(types, state) if opts[:exclusive] == true
      Array(state == :both ? %w(down up) : state).each do |state|
        types.each {|type| responses[type.to_sym][state.to_sym] << block}
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
    def no_response_to(types = nil, state = :both)
      types = Array(types)
      Array(state == :both ? %w(down up) : state).each do |state|
        types.each {|type| responses[type.to_sym][state.to_sym].clear}
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
    
    # Reponds to an action by executing all matching responses.
    # 
    # Parameters:
    # 
    # [+action+]  hash containing an action from Launchpad::Device.read_pending_actions
    def respond_to_action(action)
      type = action[:type].to_sym
      state = action[:state].to_sym
      (responses[type][state] + responses[:all][state]).each {|block| block.call(self, action)}
      nil
    end
    
  end
  
end