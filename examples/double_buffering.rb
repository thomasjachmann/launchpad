require File.expand_path('../setup', __FILE__)

interaction = Launchpad::Interaction.new

# store and change button states, ugly but well...
@button_states = [
  [false, false, false, false, false, false, false, false],
  [false, false, false, false, false, false, false, false],
  [[false, false], [false, false], [false, false], [false, false], [false, false], [false, false], [false, false], [false, false]],
  [[false, false], [false, false], [false, false], [false, false], [false, false], [false, false], [false, false], [false, false]],
  [[false, false], [false, false], [false, false], [false, false], [false, false], [false, false], [false, false], [false, false]],
  [[false, false], [false, false], [false, false], [false, false], [false, false], [false, false], [false, false], [false, false]],
  [[false, false], [false, false], [false, false], [false, false], [false, false], [false, false], [false, false], [false, false]],
  [[false, false], [false, false], [false, false], [false, false], [false, false], [false, false], [false, false], [false, false]]
]
def change_button_state(action)
  if action[:y] > 1
    which = @active_buffer_button == :user2 ? 1 : 0
    @button_states[action[:y]][action[:x]][which] = !@button_states[action[:y]][action[:x]][which]
  else
    @button_states[action[:y]][action[:x]] = !@button_states[action[:y]][action[:x]]
  end
end

# setup grid buttons to:
# * set LEDs in normal mode on the first row
# * set LEDs in flashing mode on the second row
# * set LEDs in buffering mode on all other rows
interaction.response_to(:grid, :down) do |interaction, action|
  color = change_button_state(action) ? @color : {}
  case action[:y]
  when 0
    interaction.device.change(:grid, action.merge(color))
  when 1
    interaction.device.buffering_mode(:flashing => false, :display_buffer => 1, :update_buffer => 0)
    interaction.device.change(:grid, action.merge(color).merge(:mode => :flashing))
    interaction.respond_to(@active_buffer_button, :down)
  else
    interaction.device.change(:grid, action.merge(color).merge(:mode => :buffering))
  end
end

# green feedback for buffer buttons
interaction.response_to([:session, :user1, :user2], :down) do |interaction, action|
  case @active_buffer_button = action[:type]
  when :session
    interaction.device.buffering_mode(:flashing => true)
  when :user1
    interaction.device.buffering_mode(:display_buffer => 0, :update_buffer => 0)
  when :user2
    interaction.device.buffering_mode(:display_buffer => 1, :update_buffer => 1)
  end
  interaction.device.change(:session, :red => @active_buffer_button == :session ? :hi : :lo, :green => @active_buffer_button == :session ? :hi : :lo)
  interaction.device.change(:user1, :red => @active_buffer_button == :user1 ? :hi : :lo, :green => @active_buffer_button == :user1 ? :hi : :lo)
  interaction.device.change(:user2, :red => @active_buffer_button == :user2 ? :hi : :lo, :green => @active_buffer_button == :user2 ? :hi : :lo)
end

# setup color picker
def display_color(opts)
  lambda do |interaction, action|
    @red = opts[:red] if opts[:red]
    @green = opts[:green] if opts[:green]
    if @red == 0 && @green == 0
      @red = 1 if opts[:red]
      @green = 1 if opts[:green]
    end
    @color = {:red => @red, :green => @green}
    on = {:red => 3, :green => 3}
    interaction.device.change(:scene1, @red == 3 ? on : {:red => 3})
    interaction.device.change(:scene2, @red == 2 ? on : {:red => 2})
    interaction.device.change(:scene3, @red == 1 ? on : {:red => 1})
    interaction.device.change(:scene4, @red == 0 ? on : {:red => 0})
    interaction.device.change(:scene5, @green == 3 ? on : {:green => 3})
    interaction.device.change(:scene6, @green == 2 ? on : {:green => 2})
    interaction.device.change(:scene7, @green == 1 ? on : {:green => 1})
    interaction.device.change(:scene8, @green == 0 ? on : {:green => 0})
  end
end
# register color picker interactors on scene buttons
interaction.response_to(:scene1, :down, :exclusive => true, &display_color(:red => 3))
interaction.response_to(:scene2, :down, :exclusive => true, &display_color(:red => 2))
interaction.response_to(:scene3, :down, :exclusive => true, &display_color(:red => 1))
interaction.response_to(:scene4, :down, :exclusive => true, &display_color(:red => 0))
interaction.response_to(:scene5, :down, :exclusive => true, &display_color(:green => 3))
interaction.response_to(:scene6, :down, :exclusive => true, &display_color(:green => 2))
interaction.response_to(:scene7, :down, :exclusive => true, &display_color(:green => 1))
interaction.response_to(:scene8, :down, :exclusive => true, &display_color(:green => 0))
# pick green
interaction.respond_to(:scene5, :down)

# mixer button terminates interaction on button up
interaction.response_to(:mixer) do |interaction, action|
  interaction.device.change(:mixer, :red => action[:state] == :down ? :hi : :off)
  interaction.stop if action[:state] == :up
end

# start in auto flashing mode
interaction.respond_to(:session, :down)

# start interacting
interaction.start

# sleep so that the messages can be sent before the program terminates
sleep 0.1
