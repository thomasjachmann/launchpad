require "#{File.dirname(__FILE__)}/../lib/launchpad"

l = Launchpad.new(:input => false, :output => true)

sleep 1

pos_x = pos_y = 0
4.times do |red|
  4.times do |green|
    l.single :x => pos_x, :y => pos_y, :red => red, :green => green, :mode => :buffering
    l.single :x => 7 - pos_x, :y => pos_y, :red => red, :green => green, :mode => :buffering
    l.single :x => pos_x, :y => 7 - pos_y, :red => red, :green => green, :mode => :buffering
    l.single :x => 7 - pos_x, :y => 7 - pos_y, :red => red, :green => green, :mode => :buffering
    pos_y += 1
  end
  pos_x += 1
  pos_y = 0
end

sleep 1
