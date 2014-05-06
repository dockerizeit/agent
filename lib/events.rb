# This module groups tasks related to consuming the
# /events Docker API endpoint

module Events
  require 'events/reader'
  require 'events/publisher'

  # Listens for events and notifies them using the given bus
  # Returns the Events::Reader object,
  def self.notify_on(bus)
    publisher = Publisher.new(bus)
    reader = Reader.new
    reader.start! &publisher.method(:handle_event)
    return reader
  end
end
