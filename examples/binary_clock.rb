require File.join(File.dirname(__FILE__), 'setup')

device = Launchpad::Device.new
device.reset

on = { :red => :high, :green => :off }
off = { :red => :off, :green => :lo }

digit_map = [
  [off, off, off, off],
  [on , off, off, off],
  [off, on , off, off],
  [on , on , off, off],
  [off, off, on , off],
  [on , off, on , off],
  [off, on , on , off],
  [on , on , on , off],
  [off, off, off, on ],
  [on , off, off, on ]
]

while true do
  Time.now.strftime('%H%M%S').split('').each_with_index do |digit, x|
    digit_map[digit.to_i].each_with_index do |color, y|
      device.change :grid, color.merge(:x => x, :y => (7 - y))
    end
  end

  sleep 0.25
end