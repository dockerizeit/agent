require 'faye/websocket'
require 'eventmachine'
require 'json'
require 'digest/sha1'

require 'commands'

class Agent

  COMMANDS = {
    'containers' => Commands::Containers.new
  }

  def initialize(config)
    @config = config
    @stop_requested = false
    Signal.trap('TERM') { stop! }
    Signal.trap('KILL') { stop! }
  end


  ## ATTR READERS
  [:api_key, :api_secret, :agent_name, :remote_api, :keep_alive_period].each do |m|
    define_method m do
      @config[m]
    end
  end
  ## END ATTR READERS

  def start!
    until stop_requested?
      loop
      sleep 1 unless stop_requested?
    end
  end

  def stop!
    @stop_requested = true
    EM.stop_event_loop if EM.reactor_running?
  end

  def stop_requested?
    @stop_requested
  end

  def handle_response(data)
    if data["success"] == true
      if data["action"] == 'connection/auth'
        EM.add_periodic_timer keep_alive_period do
          payload = { action: 'connection/ping', at: Time.now.utc }.to_json
          log :ping, payload
          @ws.send payload
        end
      else
        log :message, '/!\ Unknown action', data
      end
    else
      log :message, '/!\ Failure response', data
    end
  end

  def handle_command(data)
    action = data.delete('action')
    req_id = data.delete('req_id')
    if action.nil?
      log :message, '/!\ No action', data
    else
      command, operation = action.split('/', 2)
      handler = COMMANDS[command]
      if handler
        response = handler.handle(operation, data)
        response[:action] = action
        response[:req_id] = req_id
        json = response.to_json
        log :message_response, json
        @ws.send(json)
      end
    end
  end

  def is_response?(data) 
    return data.has_key? 'success'
  end

  def loop
    EM.run do
      @ws = Faye::WebSocket::Client.new(remote_api)

      @ws.on :open do |event|
        hashed_key = Base64.encode64(Digest::SHA1.digest(api_key + api_secret))
        credentials = { key: api_key, challenge: hashed_key}
        payload = {action: 'connection/auth', name: agent_name, credentials: credentials}
        log :open, payload
        @ws.send(payload.to_json)
      end

      @ws.on :message do |event|
        data = JSON.parse(event.data)
        log :message, event.data
        start = Time.now
        if is_response?(data)
          handle_response(data) 
        else
          handle_command(data)
        end
        log :event_runtime, "%0.6fms" % (Time.now - start), event.data
      end

      @ws.on :close do |event|
        log :close, event.code, event.reason
        @ws = nil
        EM::stop_event_loop
      end
    end
  end

  def log(*arguments)
    p [Time.now, api_key, arguments]
  end

end
