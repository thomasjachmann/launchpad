require 'helper'

class BreakError < StandardError; end

class TestInteraction < Test::Unit::TestCase
  
  context 'initializer' do
    
    should 'leave device empty if not given' do
      assert_nil Launchpad::Interaction.new.device
    end
    
    should 'initialize device if given' do
      assert_equal 'device', Launchpad::Interaction.new(:device => 'device').device
    end
    
    should 'not be active' do
      assert !Launchpad::Interaction.new.active
    end
    
  end
  
  context 'start' do
    
    # this is kinda greybox tested, since I couldn't come up with another way to test a loop [thomas, 2009-11-11]
    
    setup do
      @interaction = Launchpad::Interaction.new
      @device = Launchpad::Device.new
      Launchpad::Device.stubs(:new).returns(@device)
    end
    
    context 'up until read_pending_actions' do
      
      setup do
        @device.stubs(:read_pending_actions).raises(BreakError)
      end
      
      should 'create new device' do
        begin
          Launchpad::Device.expects(:new).with(:input => true, :output => true).returns(@device)
          @interaction.start
          fail 'should raise BreakError'
        rescue BreakError
          assert_same @device, @interaction.device
        end
      end
      
      should 'create new device with given device_name' do
        begin
          @interaction = Launchpad::Interaction.new(:device_name => 'given')
          Launchpad::Device.expects(:new).with(:input => true, :output => true, :device_name => 'given').returns(@device)
          @interaction.start
          fail 'should raise BreakError'
        rescue BreakError
          assert_same @device, @interaction.device
        end
      end
      
      should 'not create new device when one is given' do
        begin
          @interaction = Launchpad::Interaction.new(:device => @device)
          assert_same @device, @interaction.device
          Launchpad::Device.expects(:new).never
          @interaction.start
          fail 'should raise BreakError'
        rescue BreakError
          assert_same @device, @interaction.device
        end
      end
      
      should 'set active to true' do
        begin
          @interaction.start
          fail 'should raise BreakError'
        rescue BreakError
          assert @interaction.active
        end
      end
      
    end
    
    should 'raise CommunicationError when Portmidi::DeviceError occurs' do
      @device.stubs(:read_pending_actions).raises(Portmidi::DeviceError.new(0))
      assert_raise Launchpad::CommunicationError do
        @interaction.start
      end
    end
    
    should 'call respond_to_action with actions from respond_to_action' do
      begin
        @interaction.stubs(:sleep).raises(BreakError)
        @device.stubs(:read_pending_actions).returns(['message1', 'message2'])
        @interaction.expects(:respond_to_action).with('message1').once
        @interaction.expects(:respond_to_action).with('message2').once
        @interaction.start
        fail 'should raise BreakError'
      rescue BreakError
      end
    end
    
    context 'sleep' do
      
      setup do
        @device.stubs(:read_pending_actions).returns([])
      end
      
      should 'sleep with default latency of 0.001 when none given' do
        begin
          @interaction.expects(:sleep).with(0.001).raises(BreakError)
          @interaction.start
          fail 'should raise BreakError'
        rescue BreakError
        end
      end
      
      should 'sleep with given latency' do
        begin
          @interaction = Launchpad::Interaction.new(:latency => 4)
          @interaction.expects(:sleep).with(4).raises(BreakError)
          @interaction.start
          fail 'should raise BreakError'
        rescue BreakError
        end
      end
      
      should 'not sleep when latency is <= 0' # TODO don't know how to test this [thomas, 2009-11-11]
      
    end
    
    should 'reset the device after the loop' # TODO don't know how to test this [thomas, 2009-11-11]
    
  end
  
  context 'stop' do
    
    should 'set active to false' do
      i = Launchpad::Interaction.new
      i.instance_variable_set('@active', true)
      assert i.active
      i.stop
      assert !i.active
    end
    
  end
  
  context 'response_to/no_response_to/respond_to' do
    
    setup do
      @interaction = Launchpad::Interaction.new
    end
    
    should 'call responses that match, and not others' do
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
    
    should 'not call responses when they are deregistered' do
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
    
    should 'not call responses registered for both when removing for one of both states' do
      @interaction.response_to(:mixer, :both) {|i, a| @mixer = true}
      @interaction.no_response_to(:mixer, :down)
      @interaction.respond_to(:mixer, :down)
      assert !@mixer
      @interaction.respond_to(:mixer, :up)
      assert @mixer
    end
    
    should 'remove other responses when adding a new exclusive response' do
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
  
end
