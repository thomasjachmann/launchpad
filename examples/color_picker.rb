require File.join(File.dirname(__FILE__), 'setup')

interaction = Launchpad::Interaction.new

# build color arrays for color display views
colors_single = [
  [ 0,  1,  2,  3,  0,  0,  0,  0],
  [16, 17, 18, 19,  0,  0,  0,  0],
  [32, 33, 34, 35,  0,  0,  0,  0],
  [48, 49, 50, 51,  0,  0,  0,  0],
  [0] * 8,
  [0] * 8,
  [0] * 8,
  [0] * 8,
  [0] * 8
]
colors_double = [
  [ 0,  0,  1,  1,  2,  2,  3,  3],
  [ 0,  0,  1,  1,  2,  2,  3,  3],
  [16, 16, 17, 17, 18, 18, 19, 19],
  [16, 16, 17, 17, 18, 18, 19, 19],
  [32, 32, 33, 33, 34, 34, 35, 35],
  [32, 32, 33, 33, 34, 34, 35, 35],
  [48, 48, 49, 49, 50, 50, 51, 51],
  [48, 48, 49, 49, 50, 50, 51, 51],
  [0] * 8
]
colors_mirrored = [
  [ 0,  1,  2,  3,  3,  2,  1,  0],
  [16, 17, 18, 19, 19, 18, 17, 16],
  [32, 33, 34, 35, 35, 34, 33, 32],
  [48, 49, 50, 51, 51, 50, 49, 48],
  [48, 49, 50, 51, 51, 50, 49, 48],
  [32, 33, 34, 35, 35, 34, 33, 32],
  [16, 17, 18, 19, 19, 18, 17, 16],
  [ 0,  1,  2,  3,  3,  2,  1,  0],
  [0] * 8
]

# setup color display views
def display_color_view(colors)
  lambda do |interaction, action|
    # set color
    interaction.device.change_all(colors)
    # register mute interactor on scene buttons
    interaction.response_to(%w(scene1 scene2 scene3 scene4 scene5 scene6 scene7 scene8), :down, :exclusive => true, &@mute)
  end
end
interaction.response_to(:up, :down, &display_color_view(colors_single + [48, 16, 16, 16]))
interaction.response_to(:down, :down, &display_color_view(colors_double + [16, 48, 16, 16]))
interaction.response_to(:left, :down, &display_color_view(colors_mirrored + [16, 16, 48, 16]))

# setup color picker view
def display_color(opts)
  lambda do |interaction, action|
    @red = opts[:red] if opts[:red]
    @green = opts[:green] if opts[:green]
    colors = [(@green * 16 + @red)] * 64
    scenes = [@red == 3 ? 51 : 3, @red == 2 ? 51 : 2, @red == 1 ? 51 : 1, @red == 0 ? 51 : 0, @green == 3 ? 51 : 48, @green == 2 ? 51 : 32, @green == 1 ? 51 : 16, @green == 0 ? 51 : 0]
    interaction.device.change_all(colors + scenes + [16, 16, 16, 48])
  end
end
interaction.response_to(:right, :down) do |interaction, action|
  @red = 0
  @green = 0
  # register color picker interactors on scene buttons
  interaction.response_to(:scene1, :down, :exclusive => true, &display_color(:red => 3))
  interaction.response_to(:scene2, :down, :exclusive => true, &display_color(:red => 2))
  interaction.response_to(:scene3, :down, :exclusive => true, &display_color(:red => 1))
  interaction.response_to(:scene4, :down, :exclusive => true, &display_color(:red => 0))
  interaction.response_to(:scene5, :down, :exclusive => true, &display_color(:green => 3))
  interaction.response_to(:scene6, :down, :exclusive => true, &display_color(:green => 2))
  interaction.response_to(:scene7, :down, :exclusive => true, &display_color(:green => 1))
  interaction.response_to(:scene8, :down, :exclusive => true, &display_color(:green => 0))
  # display color
  interaction.respond_to(:scene8, :down)
end

# mixer button terminates interaction on button up
interaction.response_to(:mixer) do |interaction, action|
  interaction.device.change(:mixer, :red => action[:state] == :down ? :hi : :off)
  interaction.stop if action[:state] == :up
end

# setup mute display interactors on all unused buttons
@mute = display_color_view([0] * 72 + [16, 16, 16, 16])
interaction.response_to(%w(session user1 user2 grid), :down, &@mute)

# display mute view
interaction.respond_to(:session, :down)

# start interacting
interaction.start

# sleep so that the messages can be sent before the program terminates
sleep 0.1
