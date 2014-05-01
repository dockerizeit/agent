module Service
  module Connection

    def actions
      [:connection]
    end

    def auth_ok(message)
      agent.authorized(message['token'])
      no_response
    end

    def auth_fail(message)
      agent.log :auth, :fail, message
      agent.stop! if message["status"] == 401 # unauthorized
      no_response
    end

  end
end
