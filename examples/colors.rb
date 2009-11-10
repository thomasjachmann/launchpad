require File.join(File.dirname(__FILE__), 'setup')

device = Launchpad::Device.new(:input => false, :output => true)

pos_x = pos_y = 0
4.times do |red|
  4.times do |green|
    device.change :grid, :x => pos_x, :y => pos_y, :red => red, :green => green
    device.change :grid, :x => 7 - pos_x, :y => pos_y, :red => red, :green => green
    device.change :grid, :x => pos_x, :y => 7 - pos_y, :red => red, :green => green
    device.change :grid, :x => 7 - pos_x, :y => 7 - pos_y, :red => red, :green => green
    pos_y += 1
    # sleep, otherwise the connection drops some messages - WTF?
    sleep 0.01
  end
  pos_x += 1
  pos_y = 0
end

# sleep so that the messages can be sent before the program terminates
sleep 0.1
