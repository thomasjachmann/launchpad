require 'launchpad/device'

module Launchpad
  
  class Interaction
    
    class Interactor
      
      def initialize(block, state)
        @block = block
        @state = state.to_sym
      end
      
      def act_if_responsible(device, action)
        @block.call(device, action) if @state == :both || @state == action[:state]
      end
      
    end
    
    attr_reader :device, :interacting
    
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
      @interacting = false
    end
    
    # Starts interacting with the launchpad, blocking
    def start
      if @device.nil?
        device_opts = {:input => true, :output => true}
        device_opts[:device_name] = @device_name unless @device_name.nil?
        @device = Device.new(device_opts)
      end
      @interacting = true
      while @interacting do
        @device.pending_user_actions.each {|action| call_interactors(action)}
        sleep @latency unless @latency == 0
      end
      @device.reset
    rescue Portmidi::DeviceError => e
      raise CommunicationError.new(e)
    end
    
    # Stops interacting with the launchpad
    def stop
      @interacting = false
    end
    
    # Registers an interactor
    # types => the type of event to react on, one or more of :all, :grid, :up, :down, :left, :right, :session, :user1, :user2, :mixer, :scene1 - :scene8, optional, defaults to :all
    # state => which state transition to react to, one of :down, :up, :both, optional, defaults to :both
    def register_interactor(types = :all, state = :both, &block)
      Array(types).each do |type|
        interactors[type.to_sym] << Interactor.new(block, state)
      end
    end
    
    # Clears interactors
    # type  => the type of interactor to clear, one of :all (not meaning "all interactors" but "interactors registered for type :all"), :grid, :up, :down, :left, :right, :session, :user1, :user2, :mixer, :scene1 - :scene8, optional, defaults to nil (meaning "all interactors")
    def clear_interactors(type = nil)
      (type.nil? ? interactors : interactors[type.to_sym]).clear
    end
    
    # Calls interactors
    # action => see Launchpad::Device#pending_user_actions
    def call_interactors(action)
      (interactors[action[:type].to_sym] + interactors[:all]).each do |interactor|
        interactor.act_if_responsible(@device, action)
      end
    end
    
    private
    
    def interactors
      @interactors ||= Hash.new {|hash, key| hash[key] = []}
    end
    
  end
  
end