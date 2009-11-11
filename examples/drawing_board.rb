require File.join(File.dirname(__FILE__), 'setup')

interaction = Launchpad::Interaction.new

flags = Hash.new(false)

# yellow feedback for grid buttons
interaction.response_to(:grid, :down) do |interaction, action|
  coord = 16 * action[:y] + action[:x]
  brightness = flags[coord] ? :off : :hi
  flags[coord] = !flags[coord]
  interaction.device.change(:grid, action.merge(:red => brightness, :green => brightness))
end

# mixer button terminates interaction on button up
interaction.response_to(:mixer) do |interaction, action|
  interaction.device.change(:mixer, :red => action[:state] == :down ? :hi : :off)
  interaction.stop if action[:state] == :up
end

# start interacting
interaction.start

# sleep so that the messages can be sent before the program terminates
sleep 0.1
