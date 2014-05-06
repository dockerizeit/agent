class Events::Reader
  # Forks a new thread and monitors the /events Docker API endpoint.
  #
  # Parsed events are given to the event_handler_block as Docker::Event instances
  def start!(&event_handler_block)
    stop! if @thread
    @thread = Thread.new do
      Docker::Event.stream &event_handler_block
    end
  end

  # Stops the currently running thread and joins it so it is correctly reaped
  def stop!
    @thread.kill if @thread
    join_thread
  end

  # Allows joining the currently running thread and clears it after that
  def join_thread
    @thread.join if @thread
    @thread = nil
  end
end
