require 'helper'

class BreakError < StandardError; end

describe Launchpad::Interaction do

  describe '#initialize' do
    
    it 'creates device if not given' do
      Launchpad::Device.expects(:new).with(:input => true, :output => true).returns('device')
      assert_equal 'device', Launchpad::Interaction.new.device
    end
    
    it 'creates device with given device_name' do
      Launchpad::Device.expects(:new).with(:device_name => 'device', :input => true, :output => true).returns('device')
      assert_equal 'device', Launchpad::Interaction.new(:device_name => 'device').device
    end
    
    it 'creates device with given input_device_id/output_device_id' do
      Launchpad::Device.expects(:new).with(:input_device_id => 'in', :output_device_id => 'out', :input => true, :output => true).returns('device')
      assert_equal 'device', Launchpad::Interaction.new(:input_device_id => 'in', :output_device_id => 'out').device
    end
    
    it 'initializes device if given' do
      assert_equal 'device', Launchpad::Interaction.new(:device => 'device').device
    end
    
    it 'is not be active' do
      assert !Launchpad::Interaction.new.active
    end
    
  end
  
  describe '#close' do
    
    it 'is not be active' do
      interaction = Launchpad::Interaction.new
      interaction.start(:detached => true)
      interaction.close
      assert !interaction.active
    end
    
    it 'closes device' do
      interaction = Launchpad::Interaction.new(:device => device = Launchpad::Device.new)
      device.expects(:close)
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
      @interaction = Launchpad::Interaction.new(:device => @device = Launchpad::Device.new)
    end
    
    after do
      mocha_teardown # so that expectations on Thread.join don't fail in here
      begin
        @interaction.close
      rescue
        # ignore, should be handled in tests, this is just to close all the spawned threads
      end
    end
    
    # this is kinda greybox tested, since I couldn't come up with another way to test thread handling [thomas, 2010-01-24]
    it 'sets active to true in blocking mode' do
      t = Thread.new {}
      Thread.expects(:new).returns(t)
      @interaction.start
      assert @interaction.active
    end
    
    it 'sets active to true in detached mode' do
      @interaction.start(:detached => true)
      assert @interaction.active
    end
    
    # this is kinda greybox tested, since I couldn't come up with another way to test thread handling [thomas, 2010-01-24]
    it 'starts a new thread and block in blocking mode' do
      t = Thread.new {}
      Thread.expects(:new).returns(t)
      t.expects(:join).once
      @interaction.start
    end
    
    # this is kinda greybox tested, since I couldn't come up with another way to test thread handling [thomas, 2010-01-24]
    it 'starts a new thread and return in detached mode' do
      t = Thread.new {}
      Thread.expects(:new).returns(t)
      t.expects(:join).never
      @interaction.start(:detached => true)
    end
    
    it 'raises CommunicationError when Portmidi::DeviceError occurs' do
      @device.stubs(:read_pending_actions).raises(Portmidi::DeviceError.new(0))
      assert_raises Launchpad::CommunicationError do
        @interaction.start
      end
    end
    
    # this is kinda greybox tested, since I couldn't come up with another way to test thread handling [thomas, 2010-01-24]
    it 'calls respond_to_action with actions from respond_to_action' do
      @interaction.stubs(:sleep).raises(BreakError)
      @device.stubs(:read_pending_actions).returns(['message1', 'message2'])
      @interaction.expects(:respond_to_action).with('message1').once
      @interaction.expects(:respond_to_action).with('message2').once
      @interaction.start(:detached => true)
    end
    
    # this is kinda greybox tested, since I couldn't come up with another way to test thread handling [thomas, 2010-01-24]
    describe 'latency' do
      
      before do
        @device.stubs(:read_pending_actions).returns([])
      end
      
      it 'sleeps with default latency of 0.001 when none given' do
        assert_raises BreakError do
          @interaction.expects(:sleep).with(0.001).raises(BreakError)
          @interaction.start
        end
      end
      
      it 'sleeps with given latency' do
        assert_raises BreakError do
          @interaction = Launchpad::Interaction.new(:latency => 4, :device => @device)
          @interaction.expects(:sleep).with(4).raises(BreakError)
          @interaction.start
        end
      end
      
      it 'sleeps with absolute value of given negative latency' do
        assert_raises BreakError do
          @interaction = Launchpad::Interaction.new(:latency => -3.1, :device => @device)
          @interaction.expects(:sleep).with(3.1).raises(BreakError)
          @interaction.start
        end
      end
      
      it 'does not sleep when latency is 0' do
        @interaction = Launchpad::Interaction.new(:latency => 0, :device => @device)
        @interaction.expects(:sleep).never
        @interaction.start(:detached => true)
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
    
    it 'sets active to false in blocking mode' do
      i = Launchpad::Interaction.new
      begin
        t = Thread.new do
          i.start
        end
        assert i.active
        i.stop
        assert !i.active
      ensure
        t.join
      end
    end
    
    it 'sets active to false in detached mode' do
      i = Launchpad::Interaction.new
      i.start(:detached => true)
      assert i.active
      i.stop
      assert !i.active
    end
    
    it 'is callable anytime' do
      i = Launchpad::Interaction.new
      i.stop
      i.start(:detached => true)
      i.stop
      i.stop
    end
    
    # this is kinda greybox tested, since I couldn't come up with another way to test thread handling [thomas, 2010-01-24]
    it 'calls run and joins on a running reader thread' do
      t = Thread.new {sleep}
      Thread.expects(:new).returns(t)
      t.expects(:run)
      t.expects(:join)
      i = Launchpad::Interaction.new
      i.start(:detached => true)
      i.stop
    end
    
    # this is kinda greybox tested, since I couldn't come up with another way to test tread handling [thomas, 2010-01-24]
    it 'raises pending exceptions in detached mode' do
      t = Thread.new {raise BreakError}
      Thread.expects(:new).returns(t)
      i = Launchpad::Interaction.new
      i.start(:detached => true)
      assert_raises BreakError do
        i.stop
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
    
  end
  
  describe 'regression tests' do
    
    it 'does not raise an exception when calling stop within a response in attached mode' do
      i = Launchpad::Interaction.new
      # strangely, you have to sleep 0.001 or do anything else before
      # calling i.stop - the ThreadError won't be thrown otherwise...
      i.response_to(:mixer, :down) {|i,a| sleep 0.001; i.stop}
      i.device.stubs(:read_pending_actions).returns([{
        :timestamp  => 0,
        :state      => :down,
        :type       => :mixer
      }])
      Thread.new do
        i.start
      end.join
    end
    
  end
  
end
