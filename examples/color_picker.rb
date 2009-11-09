require File.join(File.dirname(__FILE__), 'setup')

# need to declare as instance variables here for being able to access
# @interaction within interactors created by create_interactor_block
device = Launchpad::Device.new
@interaction = Launchpad::Interaction.new(:device => device)

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
  lambda do |device, action|
    # set color
    device.change_all(colors)
    (1..8).each do |i|
      # deregister color picker interactor
      @interaction.clear_interactors(:"scene#{i}")
      # register mute interactor
      @interaction.register_interactor(:"scene#{i}", :down, &@mute)
    end
  end
end
@interaction.register_interactor(:up, :down, &display_color_view(colors_single + [48, 16, 16, 16]))
@interaction.register_interactor(:down, :down, &display_color_view(colors_double + [16, 48, 16, 16]))
@interaction.register_interactor(:left, :down, &display_color_view(colors_mirrored + [16, 16, 48, 16]))

# setup color picker view
def display_color(opts)
  lambda do |device, action|
    @red = opts[:red] if opts[:red]
    @green = opts[:green] if opts[:green]
    colors = [(@green * 16 + @red)] * 64
    scenes = [@red == 3 ? 51 : 3, @red == 2 ? 51 : 2, @red == 1 ? 51 : 1, @red == 0 ? 51 : 0, @green == 3 ? 51 : 48, @green == 2 ? 51 : 32, @green == 1 ? 51 : 16, @green == 0 ? 51 : 0]
    device.change_all(colors + scenes + [16, 16, 16, 48])
  end
end
@interaction.register_interactor(:right, :down) do |device, action|
  @red = 0
  @green = 0
  # remove mute interactors
  (1..8).each {|i| @interaction.clear_interactors(:"scene#{i}")}
  # register color picker interactors
  @interaction.register_interactor(:scene1, :down, &display_color(:red => 3))
  @interaction.register_interactor(:scene2, :down, &display_color(:red => 2))
  @interaction.register_interactor(:scene3, :down, &display_color(:red => 1))
  @interaction.register_interactor(:scene4, :down, &display_color(:red => 0))
  @interaction.register_interactor(:scene5, :down, &display_color(:green => 3))
  @interaction.register_interactor(:scene6, :down, &display_color(:green => 2))
  @interaction.register_interactor(:scene7, :down, &display_color(:green => 1))
  @interaction.register_interactor(:scene8, :down, &display_color(:green => 0))
  # display color
  @interaction.call_interactors(:type => :scene8, :state => :down)
end

# mixer button terminates interaction on button up
@interaction.register_interactor(:mixer) do |device, action|
  device.change(:type => :mixer, :red => action[:state] == :down ? :hi : :off)
  @interaction.stop if action[:state] == :up
end

# setup mute display interactors on all unused buttons
@mute = display_color_view([0] * 72 + [16, 16, 16, 16])
@interaction.register_interactor([:session, :user1, :user2, :grid], :down, &@mute)

# display mute view
@interaction.call_interactors(:type => :session, :state => :down)

# start interacting
@interaction.start

# sleep so that the messages can be sent before the program terminates
sleep 0.1
