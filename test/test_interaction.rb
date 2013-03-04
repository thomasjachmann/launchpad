require 'helper'
require 'timeout'

class BreakError < StandardError; end

describe Launchpad::Interaction do

  # returns true/false whether the operation ended or the timeout was hit
  def timeout(timeout = 0.02, &block)
    Timeout.timeout(timeout, &block)
    true
  rescue Timeout::Error
    false
  end

  describe '#initialize' do
    
    it 'creates device if not given' do
      device = Launchpad::Device.new
      Launchpad::Device.expects(:new).
        with(:input => true, :output => true, :logger => nil).
        returns(device)
      interaction = Launchpad::Interaction.new
      assert_same device, interaction.device
    end
    
    it 'creates device with given device_name' do
      device = Launchpad::Device.new
      Launchpad::Device.expects(:new).
        with(:device_name => 'device', :input => true, :output => true, :logger => nil).
        returns(device)
      interaction = Launchpad::Interaction.new(:device_name => 'device')
      assert_same device, interaction.device
    end
    
    it 'creates device with given input_device_id' do
      device = Launchpad::Device.new
      Launchpad::Device.expects(:new).
        with(:input_device_id => 'in', :input => true, :output => true, :logger => nil).
        returns(device)
      interaction = Launchpad::Interaction.new(:input_device_id => 'in')
      assert_same device, interaction.device
    end
    
    it 'creates device with given output_device_id' do
      device = Launchpad::Device.new
      Launchpad::Device.expects(:new).
        with(:output_device_id => 'out', :input => true, :output => true, :logger => nil).
        returns(device)
      interaction = Launchpad::Interaction.new(:output_device_id => 'out')
      assert_same device, interaction.device
    end
    
    it 'creates device with given input_device_id/output_device_id' do
      device = Launchpad::Device.new
      Launchpad::Device.expects(:new).
        with(:input_device_id => 'in', :output_device_id => 'out', :input => true, :output => true, :logger => nil).
        returns(device)
      interaction = Launchpad::Interaction.new(:input_device_id => 'in', :output_device_id => 'out')
      assert_same device, interaction.device
    end
    
    it 'initializes device if given' do
      device = Launchpad::Device.new
      interaction = Launchpad::Interaction.new(:device => device)
      assert_same device, interaction.device
    end

    it 'stores the logger given' do
      logger = Logger.new(nil)
      interaction = Launchpad::Interaction.new(:logger => logger)
      assert_same logger, interaction.logger
      assert_same logger, interaction.device.logger
    end
    
    it 'doesn\'t activate the interaction' do
      assert !Launchpad::Interaction.new.active
    end
    
  end

  describe '#logger=' do

    it 'stores the logger and passes it to the device as well' do
      logger = Logger.new(nil)
      interaction = Launchpad::Interaction.new
      interaction.logger = logger
      assert_same logger, interaction.logger
      assert_same logger, interaction.device.logger
    end

  end
  
  describe '#close' do

    it 'stops the interaction' do
      interaction = Launchpad::Interaction.new
      interaction.expects(:stop)
      interaction.close
    end
    
    it 'closes the device' do
      interaction = Launchpad::Interaction.new
      interaction.device.expects(:close)
      interaction.close
    end
    
  end
  
  describe '#closed?' do
    
    it 'returns false on a newly created interaction, but true after closing' do
      interaction = Launchpad::Interaction.new
      assert !interaction.closed?
      interaction.close
      assert interaction.closed?
    end
    
  end
  
  describe '#start' do
    
    before do
      @interaction = Launchpad::Interaction.new
    end
    
    after do
      mocha_teardown # so that expectations on Thread.join don't fail in here
      begin
        @interaction.close
      rescue
        # ignore, should be handled in tests, this is just to close all the spawned threads
      end
    end
    
    it 'sets active to true in blocking mode' do
      refute @interaction.active
      erg = timeout { @interaction.start }
      refute erg, 'there was no timeout'
      assert @interaction.active
    end
    
    it 'sets active to true in detached mode' do
      refute @interaction.active
      @interaction.start(:detached => true)
      assert @interaction.active
    end
    
    it 'blocks in blocking mode' do
      erg = timeout { @interaction.start }
      refute erg, 'there was no timeout'
    end
    
    it 'returns immediately in detached mode' do
      erg = timeout { @interaction.start(:detached => true) }
      assert erg, 'there was a timeout'
    end
    
    it 'raises CommunicationError when Portmidi::DeviceError occurs' do
      @interaction.device.stubs(:read_pending_actions).raises(Portmidi::DeviceError.new(0))
      assert_raises Launchpad::CommunicationError do
        @interaction.start
      end
    end

    describe 'action handling' do

      before do
        @interaction.response_to(:mixer, :down) { @mixer_down = true }
        @interaction.response_to(:mixer, :up) do |i,a|
          sleep 0.001 # sleep to make "sure" :mixer :down has been processed
          i.stop
        end
        @interaction.device.expects(:read_pending_actions).
          at_least_once.
          returns([
            {
              :timestamp  => 0,
              :state      => :down,
              :type       => :mixer
            },
            {
              :timestamp  => 0,
              :state      => :up,
              :type       => :mixer
            }
          ])
      end
      
      it 'calls respond_to_action with actions from respond_to_action in blocking mode' do
        erg = timeout(0.5) { @interaction.start }
        assert erg, 'the actions weren\'t called'
        assert @mixer_down, 'the mixer button wasn\'t pressed'
      end
      
      it 'calls respond_to_action with actions from respond_to_action in detached mode' do
        @interaction.start(:detached => true)
        erg = timeout(0.5) { while @interaction.active; sleep 0.01; end }
        assert erg, 'there was a timeout'
        assert @mixer_down, 'the mixer button wasn\'t pressed'
      end

    end
    
    describe 'latency' do
      
      before do
        @device = @interaction.device
        @times = []
        @device.instance_variable_set("@test_interaction_latency_times", @times)
        def @device.read_pending_actions
          @test_interaction_latency_times << Time.now.to_f
          []
        end
      end
      
      it 'sleeps with default latency of 0.001s when none given' do
        timeout { @interaction.start }
        assert @times.size > 1
        @times.each_cons(2) do |a,b|
          assert_in_delta 0.001, b - a, 0.01
        end
      end
      
      it 'sleeps with given latency' do
        @interaction = Launchpad::Interaction.new(:latency => 0.5, :device => @device)
        timeout(0.55) { @interaction.start }
        assert @times.size > 1
        @times.each_cons(2) do |a,b|
          assert_in_delta 0.5, b - a, 0.01
        end
      end
      
      it 'sleeps with absolute value of given negative latency' do
        @interaction = Launchpad::Interaction.new(:latency => -0.1, :device => @device)
        timeout(0.15) { @interaction.start }
        assert @times.size > 1
        @times.each_cons(2) do |a,b|
          assert_in_delta 0.1, b - a, 0.01
        end
      end
      
      it 'does not sleep when latency is 0' do
        @interaction = Launchpad::Interaction.new(:latency => 0, :device => @device)
        timeout(0.001) { @interaction.start }
        assert @times.size > 1
        @times.each_cons(2) do |a,b|
          assert_in_delta 0, b - a, 0.1
        end
      end
      
    end
    
    it 'resets the device after the loop' do
      @interaction.device.expects(:reset)
      @interaction.start(:detached => true)
      @interaction.stop
    end
    
    it 'raises NoOutputAllowedError on closed interaction' do
      @interaction.close
      assert_raises Launchpad::NoOutputAllowedError do
        @interaction.start
      end
    end
    
  end
  
  describe '#stop' do

    before do
      @interaction = Launchpad::Interaction.new
    end
    
    it 'sets active to false in blocking mode' do
      erg = timeout { @interaction.start }
      refute erg, 'there was no timeout'
      assert @interaction.active
      @interaction.stop
      assert !@interaction.active
    end
    
    it 'sets active to false in detached mode' do
      @interaction.start(:detached => true)
      assert @interaction.active
      @interaction.stop
      assert !@interaction.active
    end
    
    it 'is callable anytime' do
      @interaction.stop
      @interaction.start(:detached => true)
      @interaction.stop
      @interaction.stop
    end
    
    # this is kinda greybox tested, since I couldn't come up with another way to test tread handling [thomas, 2010-01-24]
    it 'raises pending exceptions in detached mode' do
      t = Thread.new {raise BreakError}
      Thread.expects(:new).returns(t)
      @interaction.start(:detached => true)
      assert_raises BreakError do
        @interaction.stop
      end
    end
    
  end
  
  describe '#response_to/#no_response_to/#respond_to' do
    
    before do
      @interaction = Launchpad::Interaction.new
    end
    
    it 'calls all responses that match, and not others' do
      @interaction.response_to(:mixer, :down) {|i, a| @mixer_down = true}
      @interaction.response_to(:all, :down) {|i, a| @all_down = true}
      @interaction.response_to(:all, :up) {|i, a| @all_up = true}
      @interaction.response_to(:grid, :down) {|i, a| @grid_down = true}
      @interaction.respond_to(:mixer, :down)
      assert @mixer_down
      assert @all_down
      assert !@all_up
      assert !@grid_down
    end
    
    it 'does not call responses when they are deregistered' do
      @interaction.response_to(:mixer, :down) {|i, a| @mixer_down = true}
      @interaction.response_to(:mixer, :up) {|i, a| @mixer_up = true}
      @interaction.response_to(:all, :both) {|i, a| @all_down = a[:state] == :down}
      @interaction.no_response_to(:mixer, :down)
      @interaction.respond_to(:mixer, :down)
      assert !@mixer_down
      assert !@mixer_up
      assert @all_down
      @interaction.respond_to(:mixer, :up)
      assert !@mixer_down
      assert @mixer_up
      assert !@all_down
    end
    
    it 'does not call responses registered for both when removing for one of both states' do
      @interaction.response_to(:mixer, :both) {|i, a| @mixer = true}
      @interaction.no_response_to(:mixer, :down)
      @interaction.respond_to(:mixer, :down)
      assert !@mixer
      @interaction.respond_to(:mixer, :up)
      assert @mixer
    end
    
    it 'removes other responses when adding a new exclusive response' do
      @interaction.response_to(:mixer, :both) {|i, a| @mixer = true}
      @interaction.response_to(:mixer, :down, :exclusive => true) {|i, a| @exclusive_mixer = true}
      @interaction.respond_to(:mixer, :down)
      assert !@mixer
      assert @exclusive_mixer
      @interaction.respond_to(:mixer, :up)
      assert @mixer
      assert @exclusive_mixer
    end

    it 'allows for multiple types' do
      @downs = []
      @interaction.response_to([:up, :down], :down) {|i, a| @downs << a[:type]}
      @interaction.respond_to(:up, :down)
      @interaction.respond_to(:down, :down)
      @interaction.respond_to(:up, :down)
      assert_equal [:up, :down, :up], @downs
    end
    
  end
  
  describe 'regression tests' do
    
    it 'does not raise an exception or write an error to the logger when calling stop within a response in attached mode' do
      log = StringIO.new
      logger = Logger.new(log)
      logger.level = Logger::ERROR
      i = Launchpad::Interaction.new(:logger => logger)
      i.response_to(:mixer, :down) {|i,a| i.stop}
      i.device.expects(:read_pending_actions).
        at_least_once.
        returns([{
          :timestamp  => 0,
          :state      => :down,
          :type       => :mixer
        }])
      erg = timeout { i.start }
      # assert erg, 'the actions weren\'t called'
      assert_equal '', log.string
    end
    
  end
  
end
