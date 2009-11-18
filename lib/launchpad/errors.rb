module Launchpad
  
  # Generic launchpad error.
  class LaunchpadError < StandardError; end
  
  # Error raised when the MIDI device specified doesn't exist.
  class NoSuchDeviceError < LaunchpadError; end
  
  # Error raised when the MIDI device specified is busy.
  class DeviceBusyError < LaunchpadError; end
  
  # Error raised when an input has been requested, although
  # launchpad has been initialized without input.
  class NoInputAllowedError < LaunchpadError; end
  
  # Error raised when an output has been requested, although
  # launchpad has been initialized without output.
  class NoOutputAllowedError < LaunchpadError; end
  
  # Error raised when <tt>x/y</tt> coordinates outside of the grid
  # or none were specified.
  class NoValidGridCoordinatesError < LaunchpadError; end
  
  # Error raised when wrong brightness was specified.
  class NoValidBrightnessError < LaunchpadError; end
  
  # Error raised when anything fails while communicating
  # with the launchpad.
  class CommunicationError < LaunchpadError
    attr_accessor :source
    def initialize(e)
      super(e.portmidi_error)
      self.source = e
    end
  end
  
end
