require 'launchpad/device'

module Launchpad
  
  class Interaction
    
    attr_reader :device, :active
    
    # Initializes the launchpad interaction
    # {
    #   :device       => Launchpad::Device instance, optional
    #   :device_name  => Name of the MIDI device to use, optional, defaults to Launchpad, ignored when :device is specified
    #   :latency      => delay (in s, fractions allowed) between MIDI pulls, optional, defaults to 0.001
    # }
    def initialize(opts = nil)
      opts ||= {}
      @device = opts[:device]
      @device_name = opts[:device_name]
      @latency = (opts[:latency] || 0.001).to_f.abs
      @active = false
    end
    
    # Starts interacting with the launchpad, blocking
    def start
      if @device.nil?
        device_opts = {:input => true, :output => true}
        device_opts[:device_name] = @device_name unless @device_name.nil?
        @device = Device.new(device_opts)
      end
      @active = true
      while @active do
        @device.read_pending_actions.each {|action| respond_to_action(action)}
        sleep @latency unless @latency == 0
      end
      @device.reset
    rescue Portmidi::DeviceError => e
      raise CommunicationError.new(e)
    end
    
    # Stops interacting with the launchpad
    def stop
      @active = false
    end
    
    # Registers a response to one or more actions
    # types => the type of action to respond to, one or more of :all, :grid, :up, :down, :left, :right, :session, :user1, :user2, :mixer, :scene1 - :scene8, optional, defaults to :all
    # state => which state transition to respond to, one of :down, :up, :both, optional, defaults to :both
    # opts => {
    #   :exclusive => whether all other responses to the given types shall be deregistered first
    # }
    def response_to(types = :all, state = :both, opts = nil, &block)
      opts ||= {}
      no_response_to(types) if opts[:exclusive] == true
      Array(types).each do |type|
        responses[type.to_sym] << [state, block]
      end
    end
    
    # Deregisters all responses to one or more actions
    # type  => the type of response to clear, one or more of :all (not meaning "all responses" but "responses registered for type :all"), :grid, :up, :down, :left, :right, :session, :user1, :user2, :mixer, :scene1 - :scene8, optional, defaults to nil (meaning "all responses")
    def no_response_to(types = nil)
      Array(types).each do |type|
        (type.nil? ? responses : responses[type.to_sym]).clear
      end
    end
    
    # Responds to an action by executing all matching responses
    # type => the type of action to respond to, one of :grid, :up, :down, :left, :right, :session, :user1, :user2, :mixer, :scene1 - :scene8
    # state => which state transition to respond to, one of :down, :up
    # opts => {
    #   :x => x coordinate (0 based from top left)
    #   :y => y coordinate (0 based from top left)
    # }, unused unless type is :grid
    def respond_to(type, state, opts = nil)
      respond_to_action((opts || {}).merge(:type => type, :state => state))
    end
    
    private
    
    def responses
      @responses ||= Hash.new {|hash, key| hash[key] = []}
    end
    
    def respond_to_action(action)
      (responses[action[:type].to_sym] + responses[:all]).each do |state, block|
        block.call(self, action) if state == :both || state == action[:state]
      end
    end
    
  end
  
end