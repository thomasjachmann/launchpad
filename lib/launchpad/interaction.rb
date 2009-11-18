require 'launchpad/device'

module Launchpad
  
  # This class provides advanced interaction features.
  # 
  # Example:
  # 
  #   require 'rubygems'
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
    # 
    # Errors raised:
    # 
    # [Launchpad::NoSuchDeviceError] when device with ID or name specified does not exist
    # [Launchpad::DeviceBusyError] when device with ID or name specified is busy
    def initialize(opts = nil)
      opts ||= {}
      @device = opts[:device] || Device.new(opts.merge(:input => true, :output => true))
      @latency = (opts[:latency] || 0.001).to_f.abs
      @active = false
    end
    
    # Closes the interaction's device - nothing can be done with the interaction/device afterwards.
    def close
      @device.close
    end
    
    # Determines whether this interaction's device has been closed.
    def closed?
      @device.closed?
    end
    
    # Starts interacting with the launchpad, blocking. Resets the device when
    # the interaction was properly stopped via stop.
    # 
    # Errors raised:
    # 
    # [Launchpad::NoInputAllowedError] when input is not enabled on the interaction's device
    # [Launchpad::CommunicationError] when anything unexpected happens while communicating with the launchpad
    def start
      @active = true
      while @active do
        @device.read_pending_actions.each {|action| respond_to_action(action)}
        sleep @latency unless @latency <= 0
      end
      @device.reset
    rescue Portmidi::DeviceError => e
      raise CommunicationError.new(e)
    end
    
    # Stops interacting with the launchpad and resets it.
    def stop
      @active = false
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