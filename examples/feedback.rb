require File.join(File.dirname(__FILE__), 'setup')

interaction = Launchpad::Interaction.new

def brightness(action)
  action[:state] == :down ? :hi : :off
end

# yellow feedback for grid buttons
interaction.response_to(:grid) do |interaction, action|
  b = brightness(action)
  interaction.device.change(:grid, action.merge(:red => b, :green => b))
end

# red feedback for top control buttons
interaction.response_to([:up, :down, :left, :right, :session, :user1, :user2, :mixer]) do |interaction, action|
  interaction.device.change(action[:type], :red => brightness(action))
end

# green feedback for scene buttons
interaction.response_to([:scene1, :scene2, :scene3, :scene4, :scene5, :scene6, :scene7, :scene8]) do |interaction, action|
  interaction.device.change(action[:type], :green => brightness(action))
end

# mixer button terminates interaction on button up
interaction.response_to(:mixer, :up) do |interaction, action|
  interaction.stop
end

# start interacting
interaction.start

# sleep so that the messages can be sent before the program terminates
sleep 0.1
