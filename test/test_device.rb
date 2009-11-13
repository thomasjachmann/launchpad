require 'helper'

class TestDevice < Test::Unit::TestCase
  
  CONTROL_BUTTONS = {
    :up       => 0x68,
    :down     => 0x69,
    :left     => 0x6A,
    :right    => 0x6B,
    :session  => 0x6C,
    :user1    => 0x6D,
    :user2    => 0x6E,
    :mixer    => 0x6F
  }
  SCENE_BUTTONS = {
    :scene1   => 0x08,
    :scene2   => 0x18,
    :scene3   => 0x28,
    :scene4   => 0x38,
    :scene5   => 0x48,
    :scene6   => 0x58,
    :scene7   => 0x68,
    :scene8   => 0x78
  }
  COLORS = {
    nil => 0, 0 => 0, :off => 0,
    1 => 1, :lo => 1, :low => 1,
    2 => 2, :med => 2, :medium => 2,
    3 => 3, :hi => 3, :high => 3
  }
  STATES = {
    :down     => 127,
    :up       => 0
  }
  
  def expects_output(device, *args)
    device.instance_variable_get('@output').expects(:write).with([{:message => args, :timestamp => 0}])
  end
  
  def stub_input(device, *args)
    device.instance_variable_get('@input').stubs(:read).returns(args)
  end
  
  context 'initializer' do
    
    should 'try to initialize both input and output when not specified' do
      Portmidi.expects(:input_devices).returns(mock_devices)
      Portmidi.expects(:output_devices).returns(mock_devices)
      d = Launchpad::Device.new
      assert_not_nil d.instance_variable_get('@input')
      assert_not_nil d.instance_variable_get('@output')
    end
    
    should 'not try to initialize input when set to false' do
      Portmidi.expects(:input_devices).never
      d = Launchpad::Device.new(:input => false)
      assert_nil d.instance_variable_get('@input')
      assert_not_nil d.instance_variable_get('@output')
    end
    
    should 'not try to initialize output when set to false' do
      Portmidi.expects(:output_devices).never
      d = Launchpad::Device.new(:output => false)
      assert_not_nil d.instance_variable_get('@input')
      assert_nil d.instance_variable_get('@output')
    end
    
    should 'not try to initialize any of both when set to false' do
      Portmidi.expects(:input_devices).never
      Portmidi.expects(:output_devices).never
      d = Launchpad::Device.new(:input => false, :output => false)
      assert_nil d.instance_variable_get('@input')
      assert_nil d.instance_variable_get('@output')
    end
    
    should 'initialize the correct input output devices' do
      Portmidi.stubs(:input_devices).returns(mock_devices(:id => 4, :name => 'Launchpad Name'))
      Portmidi.stubs(:output_devices).returns(mock_devices(:id => 5, :name => 'Launchpad Name'))
      d = Launchpad::Device.new(:device_name => 'Launchpad Name')
      assert_equal Portmidi::Input, (input = d.instance_variable_get('@input')).class
      assert_equal 4, input.device_id
      assert_equal Portmidi::Output, (output = d.instance_variable_get('@output')).class
      assert_equal 5, output.device_id
    end
    
    should 'raise NoSuchDeviceError when requested input device does not exist' do
      assert_raise Launchpad::NoSuchDeviceError do
        Portmidi.stubs(:input_devices).returns(mock_devices(:name => 'Launchpad Input'))
        Launchpad::Device.new
      end
    end
    
    should 'raise NoSuchDeviceError when requested output device does not exist' do
      assert_raise Launchpad::NoSuchDeviceError do
        Portmidi.stubs(:output_devices).returns(mock_devices(:name => 'Launchpad Output'))
        Launchpad::Device.new
      end
    end
    
    should 'raise DeviceBusyError when requested input device is busy' do
      assert_raise Launchpad::DeviceBusyError do
        Portmidi::Input.stubs(:new).raises(RuntimeError)
        Launchpad::Device.new
      end
    end
    
    should 'raise DeviceBusyError when requested output device is busy' do
      assert_raise Launchpad::DeviceBusyError do
        Portmidi::Output.stubs(:new).raises(RuntimeError)
        Launchpad::Device.new
      end
    end
    
  end
  
  context 'close' do
    
    should 'not fail when neither input nor output are there' do
      Launchpad::Device.new(:input => false, :output => false).close
    end
    
    context 'with input and output devices' do
      
      setup do
        Portmidi::Input.stubs(:new).returns(@input = mock('input'))
        Portmidi::Output.stubs(:new).returns(@output = mock('output', :write => nil))
        @device = Launchpad::Device.new
      end
      
      should 'close input/output and raise NoInputAllowedError/NoOutputAllowedError on subsequent read/write accesses' do
        @input.expects(:close)
        @output.expects(:close)
        @device.close
        assert_raise Launchpad::NoInputAllowedError do
          @device.read_pending_actions
        end
        assert_raise Launchpad::NoOutputAllowedError do
          @device.change(:session)
        end
      end
      
    end
    
  end
  
  context 'closed?' do
    
    should 'return true when neither input nor output are there' do
      assert Launchpad::Device.new(:input => false, :output => false).closed?
    end
    
    should 'return false when initialized with input' do
      assert !Launchpad::Device.new(:input => true, :output => false).closed?
    end
    
    should 'return false when initialized with output' do
      assert !Launchpad::Device.new(:input => false, :output => true).closed?
    end
    
    should 'return false when initialized with both but true after calling close' do
      d = Launchpad::Device.new
      assert !d.closed?
      d.close
      assert d.closed?
    end
    
  end
  
  {
    :reset          => [0xB0, 0x00, 0x00],
    :flashing_on    => [0xB0, 0x00, 0x20],
    :flashing_off   => [0xB0, 0x00, 0x21],
    :flashing_auto  => [0xB0, 0x00, 0x28]
  }.each do |method, codes|
    context method do
    
      should 'raise NoOutputAllowedError when not initialized with output' do
        assert_raise Launchpad::NoOutputAllowedError do
          Launchpad::Device.new(:output => false).send(method)
        end
      end
    
      should "send #{codes.inspect}" do
        d = Launchpad::Device.new
        expects_output(d, *codes)
        d.send(method)
      end
    
    end
  end
  
  context 'test_leds' do
    
    should 'raise NoOutputAllowedError when not initialized with output' do
      assert_raise Launchpad::NoOutputAllowedError do
        Launchpad::Device.new(:output => false).test_leds
      end
    end
    
    context 'initialized with output' do
      
      setup do
        @device = Launchpad::Device.new(:input => false)
      end
      
      should 'return nil' do
        assert_nil @device.test_leds
      end
      
      COLORS.merge(nil => 3).each do |name, value|
        if value == 0
          should "send 0xB0, 0x00, 0x00 when given #{name}" do
            expects_output(@device, 0xB0, 0x00, 0x00)
            @device.test_leds(value)
          end
        else
          should "send 0xB0, 0x00, 0x7C + #{value} when given #{name}" do
            d = Launchpad::Device.new
            expects_output(@device, 0xB0, 0x00, 0x7C + value)
            value.nil? ? @device.test_leds : @device.test_leds(value)
          end
        end
      end
      
    end
    
  end
  
  context 'change' do
    
    should 'raise NoOutputAllowedError when not initialized with output' do
      assert_raise Launchpad::NoOutputAllowedError do
        Launchpad::Device.new(:output => false).change(:up)
      end
    end
    
    context 'initialized with output' do
      
      setup do
        @device = Launchpad::Device.new(:input => false)
      end
      
      should 'return nil' do
        assert_nil @device.change(:up)
      end
      
      context 'control buttons' do
        CONTROL_BUTTONS.each do |type, value|
          should "send 0xB0, #{value}, 12 when given #{type}" do
            expects_output(@device, 0xB0, value, 12)
            @device.change(type)
          end
        end
      end
      
      context 'scene buttons' do
        SCENE_BUTTONS.each do |type, value|
          should "send 0x90, #{value}, 12 when given #{type}" do
            expects_output(@device, 0x90, value, 12)
            @device.change(type)
          end
        end
      end
      
      context 'grid buttons' do
        8.times do |x|
          8.times do |y|
            should "send 0x90, #{16 * y + x}, 12 when given :grid, :x => #{x}, :y => #{y}" do
              expects_output(@device, 0x90, 16 * y + x, 12)
              @device.change(:grid, :x => x, :y => y)
            end
          end
        end
        
        should 'raise NoValidGridCoordinatesError if x is not specified' do
          assert_raise Launchpad::NoValidGridCoordinatesError do
            @device.change(:grid, :y => 1)
          end
        end
        
        should 'raise NoValidGridCoordinatesError if x is below 0' do
          assert_raise Launchpad::NoValidGridCoordinatesError do
            @device.change(:grid, :x => -1, :y => 1)
          end
        end
        
        should 'raise NoValidGridCoordinatesError if x is above 7' do
          assert_raise Launchpad::NoValidGridCoordinatesError do
            @device.change(:grid, :x => 8, :y => 1)
          end
        end
        
        should 'raise NoValidGridCoordinatesError if y is not specified' do
          assert_raise Launchpad::NoValidGridCoordinatesError do
            @device.change(:grid, :x => 1)
          end
        end
        
        should 'raise NoValidGridCoordinatesError if y is below 0' do
          assert_raise Launchpad::NoValidGridCoordinatesError do
            @device.change(:grid, :x => 1, :y => -1)
          end
        end
        
        should 'raise NoValidGridCoordinatesError if y is above 7' do
          assert_raise Launchpad::NoValidGridCoordinatesError do
            @device.change(:grid, :x => 1, :y => 8)
          end
        end
        
      end
      
      context 'colors' do
        COLORS.each do |red_key, red_value|
          COLORS.each do |green_key, green_value|
            should "send 0x90, 0, #{16 * green_value + red_value + 12} when given :red => #{red_key}, :green => #{green_key}" do
              expects_output(@device, 0x90, 0, 16 * green_value + red_value + 12)
              @device.change(:grid, :x => 0, :y => 0, :red => red_key, :green => green_key)
            end
          end
        end
        
        should 'raise NoValidBrightnessError if red is below 0' do
          assert_raise Launchpad::NoValidBrightnessError do
            @device.change(:grid, :x => 0, :y => 0, :red => -1)
          end
        end
        
        should 'raise NoValidBrightnessError if red is above 3' do
          assert_raise Launchpad::NoValidBrightnessError do
            @device.change(:grid, :x => 0, :y => 0, :red => 4)
          end
        end
        
        should 'raise NoValidBrightnessError if red is an unknown symbol' do
          assert_raise Launchpad::NoValidBrightnessError do
            @device.change(:grid, :x => 0, :y => 0, :red => :unknown)
          end
        end
        
        should 'raise NoValidBrightnessError if green is below 0' do
          assert_raise Launchpad::NoValidBrightnessError do
            @device.change(:grid, :x => 0, :y => 0, :green => -1)
          end
        end
        
        should 'raise NoValidBrightnessError if green is above 3' do
          assert_raise Launchpad::NoValidBrightnessError do
            @device.change(:grid, :x => 0, :y => 0, :green => 4)
          end
        end
        
        should 'raise NoValidBrightnessError if green is an unknown symbol' do
          assert_raise Launchpad::NoValidBrightnessError do
            @device.change(:grid, :x => 0, :y => 0, :green => :unknown)
          end
        end
        
      end
      
      context 'mode' do
        
        should 'send color + 12 when nothing given' do
          expects_output(@device, 0x90, 0, 12)
          @device.change(:grid, :x => 0, :y => 0, :red => 0, :green => 0)
        end
        
        should 'send color + 12 when given :normal' do
          expects_output(@device, 0x90, 0, 12)
          @device.change(:grid, :x => 0, :y => 0, :red => 0, :green => 0, :mode => :normal)
        end
        
        should 'send color + 8 when given :flashing' do
          expects_output(@device, 0x90, 0, 8)
          @device.change(:grid, :x => 0, :y => 0, :red => 0, :green => 0, :mode => :flashing)
        end
        
        should 'send color when given :buffering' do
          expects_output(@device, 0x90, 0, 0)
          @device.change(:grid, :x => 0, :y => 0, :red => 0, :green => 0, :mode => :buffering)
        end
        
      end
      
    end
    
  end
  
  context 'change_all' do
    
    should 'raise NoOutputAllowedError when not initialized with output' do
      assert_raise Launchpad::NoOutputAllowedError do
        Launchpad::Device.new(:output => false).change_all
      end
    end
    
    context 'initialized with output' do
      
      setup do
        @device = Launchpad::Device.new(:input => false)
      end
      
      should 'return nil' do
        assert_nil @device.change_all([0])
      end
      
      should 'fill colors with 0, set grid 0,0 to 0 and flush colors' do
        expects_output(@device, 0x90, 0, 0)
        20.times {|i| expects_output(@device, 0x92, 17, 17)}
        20.times {|i| expects_output(@device, 0x92, 12, 12)}
        @device.change_all([5] * 40)
      end
      
      should 'cut off exceeding colors, set grid 0,0 to 0 and flush colors' do
        expects_output(@device, 0x90, 0, 0)
        40.times {|i| expects_output(@device, 0x92, 17, 17)}
        @device.change_all([5] * 100)
      end
      
    end
    
  end
  
  context 'read_pending_actions' do
    
    should 'raise NoInputAllowedError when not initialized with input' do
      assert_raise Launchpad::NoInputAllowedError do
        Launchpad::Device.new(:input => false).read_pending_actions
      end
    end
    
    context 'initialized with input' do
      
      setup do
        @device = Launchpad::Device.new(:output => false)
      end
      
      context 'control buttons' do
        CONTROL_BUTTONS.each do |type, value|
          STATES.each do |state, velocity|
            should "build proper action for control button #{type}, #{state}" do
              stub_input(@device, {:timestamp => 0, :message => [0xB0, value, velocity]})
              assert_equal [{:timestamp => 0, :state => state, :type => type}], @device.read_pending_actions
            end
          end
        end
      end
      
      context 'scene buttons' do
        SCENE_BUTTONS.each do |type, value|
          STATES.each do |state, velocity|
            should "build proper action for scene button #{type}, #{state}" do
              stub_input(@device, {:timestamp => 0, :message => [0x90, value, velocity]})
              assert_equal [{:timestamp => 0, :state => state, :type => type}], @device.read_pending_actions
            end
          end
        end
      end
      
      context 'grid buttons' do
        8.times do |x|
          8.times do |y|
            STATES.each do |state, velocity|
              should "build proper action for grid button #{x},#{y}, #{state}" do
                stub_input(@device, {:timestamp => 0, :message => [0x90, 16 * y + x, velocity]})
                assert_equal [{:timestamp => 0, :state => state, :type => :grid, :x => x, :y => y}], @device.read_pending_actions
              end
            end
          end
        end
      end
      
      should 'build proper actions for multiple pending actions' do
        stub_input(@device, {:timestamp => 1, :message => [0x90, 0, 127]}, {:timestamp => 2, :message => [0xB0, 0x68, 0]})
        assert_equal [{:timestamp => 1, :state => :down, :type => :grid, :x => 0, :y => 0}, {:timestamp => 2, :state => :up, :type => :up}], @device.read_pending_actions
      end
      
    end
    
  end
  
end
