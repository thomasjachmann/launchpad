module Launchpad
  
  # Module defining constants for MIDI codes.
  module MidiCodes
    
    # Module defining MIDI status codes.
    module Status
      NIL           = 0x00
      OFF           = 0x80
      ON            = 0x90
      MULTI         = 0x92
      CC            = 0xB0
    end
    
    # Module defininig MIDI data 1 (note) codes for control buttons.
    module ControlButton
      UP            = 0x68
      DOWN          = 0x69
      LEFT          = 0x6A
      RIGHT         = 0x6B
      SESSION       = 0x6C
      USER1         = 0x6D
      USER2         = 0x6E
      MIXER         = 0x6F
    end
    
    # Module defininig MIDI data 1 (note) codes for scene buttons.
    module SceneButton
      SCENE1        = 0x08
      SCENE2        = 0x18
      SCENE3        = 0x28
      SCENE4        = 0x38
      SCENE5        = 0x48
      SCENE6        = 0x58
      SCENE7        = 0x68
      SCENE8        = 0x78
    end
    
    # Module defining MIDI data 2 (velocity) codes.
    module Velocity
      FLASHING_ON   = 0x20
      FLASHING_OFF  = 0x21
      FLASHING_AUTO = 0x28
      TEST_LEDS     = 0x7C
    end
    
  end
  
end
