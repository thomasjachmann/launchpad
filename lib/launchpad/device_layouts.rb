module Launchpad
  module DeviceLayouts
    Launchpad = {
      MIN_X: 0,
      MIN_Y: 0,
      MAX_X: 7,
      MAX_Y: 7,
      GRID_OFFSET: 0,
      GRID_STRIDE: 16,
    }.freeze

    LaunchpadMK2 = {
      BUTTON_LOCATIONS: {
        record_arm: [8, 0],
        solo: [8, 1],
        mute: [8, 2],
        stop: [8, 3],
        send_a: [8, 4],
        send_b: [8, 5],
        pan: [8, 6],
        volume: [8, 7],
      },
      MIN_X: 0,
      MIN_Y: 0,
      MAX_X: 8,
      MAX_Y: 7,
      GRID_OFFSET: 11,
      GRID_STRIDE: 10,
    }.freeze
  end
end
