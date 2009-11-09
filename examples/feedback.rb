require File.join(File.dirname(__FILE__), 'setup')

interaction = Launchpad::Interaction.new

# red feedback for grid buttons
interaction.register_interactor(:grid) do |device, action|
  device.single(:x => action[:x], :y => action[:y], :red => action[:state] ? :hi : :off)
end

# green feedback for top control buttons
interaction.register_interactor([:up, :down, :left, :right, :session, :user1, :user2, :mixer]) do |device, action|
  device.single(:type => action[:type], :green => action[:state] ? :hi : :off)
end

# yellow feedback for scene buttons
interaction.register_interactor([:scene1, :scene2, :scene3, :scene4, :scene5, :scene6, :scene7, :scene8]) do |device, action|
  brightness = action[:state] ? :hi : :off
  device.single(:type => action[:type], :red => brightness, :green => brightness)
end

# mixer button terminates interaction on button up
interaction.register_interactor(:mixer, :up) do |device, action|
  interaction.stop
end

# start interacting
interaction.start

# sleep so that the messages can be sent before the program terminates
sleep 0.1
