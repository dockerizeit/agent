class Responses::Connection < Responses::Base

  def auth(success, data)
    return start_pinging if success
    agent.log :auth, :fail, data
    agent.stop! if data["status"] == 401 # unauthorized
  end

  protected

  def start_pinging
    stop_pinging
    @ping_timer = EM.add_periodic_timer agent.keep_alive_period do
      payload = { action: 'connection/ping', at: Time.now.utc }
      agent.log :ping, payload
      agent.send payload
    end
  end

  def stop_pinging
    return unless @ping_timer
    @ping_timer.cancel
  end
end
