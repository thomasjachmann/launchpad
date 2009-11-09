require File.join(File.dirname(__FILE__), 'setup')

Launchpad::Device.new.reset

# sleep so that the messages can be sent before the program terminates
sleep 0.1
