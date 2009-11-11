require File.join(File.dirname(__FILE__), 'setup')

interaction = Launchpad::Interaction.new

current_color = {
  :red    => :hi,
  :green  => :hi,
  :mode   => :normal
}

def update_scene_buttons(d, color)
  on = {:red => :hi, :green => :hi}
  d.change(:scene1, color[:red] == :hi ? on : {:red => :hi})
  d.change(:scene2, color[:red] == :med ? on : {:red => :med})
  d.change(:scene3, color[:red] == :lo ? on : {:red => :lo})
  d.change(:scene4, color[:red] == :off ? on : {:red => :off})
  d.change(:scene5, color[:green] == :hi ? on : {:green => :hi})
  d.change(:scene6, color[:green] == :med ? on : {:green => :med})
  d.change(:scene7, color[:green] == :lo ? on : {:green => :lo})
  d.change(:scene8, color[:green] == :off ? on : {:green => :off})
  d.change(:user1, :green => color[:mode] == :normal ? :lo : :hi, :mode => :flashing)
  d.change(:user2, :green => color[:mode] == :normal ? :hi : :lo)
end

def choose_color(color, opts)
  lambda do |interaction, action|
    color.update(opts)
    update_scene_buttons(interaction.device, color)
  end
end

# register color picker interactors on scene buttons
interaction.response_to(:scene1, :down, &choose_color(current_color, :red => :hi))
interaction.response_to(:scene2, :down, &choose_color(current_color, :red => :med))
interaction.response_to(:scene3, :down, &choose_color(current_color, :red => :lo))
interaction.response_to(:scene4, :down, &choose_color(current_color, :red => :off))
interaction.response_to(:scene5, :down, &choose_color(current_color, :green => :hi))
interaction.response_to(:scene6, :down, &choose_color(current_color, :green => :med))
interaction.response_to(:scene7, :down, &choose_color(current_color, :green => :lo))
interaction.response_to(:scene8, :down, &choose_color(current_color, :green => :off))

# register mode picker interactors on user buttons
interaction.response_to(:user1, :down, &choose_color(current_color, :mode => :flashing))
interaction.response_to(:user2, :down, &choose_color(current_color, :mode => :normal))

# update scene buttons and start flashing
update_scene_buttons(interaction.device, current_color)
interaction.device.flashing_auto

# feedback for grid buttons
interaction.response_to(:grid, :down) do |interaction, action|
  #coord = 16 * action[:y] + action[:x]
  #brightness = flags[coord] ? :off : :hi
  #flags[coord] = !flags[coord]
  interaction.device.change(:grid, action.merge(current_color))
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
