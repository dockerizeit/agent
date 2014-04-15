module Service
  class Connection < Combi::Service

    def actions
      [:connection]
    end

    def auth_ok(message)
      start_pinging
    end

    def auth_fail(message)
      agent.log :auth, :fail, message
      agent.stop! if message["status"] == 401 # unauthorized
    end

    protected

    def start_pinging
      stop_pinging
      @ping_timer = EM.add_periodic_timer agent.keep_alive_period do
        message = {at: Time.now.utc}
        $bus.request 'connection', 'ping', message
        agent.log :ping, message
      end
    end

    def stop_pinging
      return unless @ping_timer
      @ping_timer.cancel
    end

    def agent
      context[:agent]
    end

  end
end
