require 'logger'

module Launchpad

  # This module provides logging facilities. Just include it to be able to log
  # stuff.
  module Logging

    # Returns the logger to be used by the current instance.
    # 
    # Returns:
    # 
    # the logger set externally or a logger that swallows everything
    def logger
      @logger ||= Logger.new(nil)
    end

    # Sets the logger to be used by the current instance.
    # 
    # [+logger+]  the [Logger] instance
    def logger=(logger)
      @logger = logger
    end

  end

end
