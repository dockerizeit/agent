require 'faye/websocket'
require 'eventmachine'
require 'json'
require 'digest/sha1'
require 'docker'

require 'commands'
require 'responses'

class Agent
  ## ATTR READERS
  [:api_key, :api_secret, :agent_name, :remote_api, :keep_alive_period].each do |m|
    define_method m do
      @config[m]
    end
  end
  ## END ATTR READERS

  def initialize(config)
    reset_back_off_delay!
    @config = config
    @stop_requested = false
    init_docker
    Signal.trap('TERM') { stop! }
    Signal.trap('KILL') { stop! }
  end

  def start!
    until stop_requested?
      loop
      back_off! unless stop_requested?
    end
  end

  def stop!
    @stop_requested = true
    EM.stop_event_loop if EM.reactor_running?
  end

  def send(payload)
    @ws.send payload.to_json
  end

  def log(*arguments)
    p [Time.now, api_key, arguments]
  end

  protected

  def init_docker
    Docker.url = "unix:///var/run/docker.sock" unless ENV['DOCKER_HOST']
    puts "Using DOCKER_URL #{Docker.url}"
    puts "Versions: #{Docker.version.inspect}"
    puts "Info: #{Docker.info.inspect}"
  end
  
  def commands 
    @commands ||= {
      'containers' => Commands::Containers.new(self)
    } 
  end
  def responses
    @responses ||= {
      'connection' => Responses::Connection.new(self)
    }
  end

  def stop_requested?
    @stop_requested
  end

  def handle_response(data)
    success = data.delete("success") == true
    action = data.delete('action')
    if action.nil?
      log :message, '/!\ No action', data
    else
      command, operation = action.split('/', 2)
      handler = responses[command]
      if handler
        handler.handle(operation, success, data)
      else
        log :message, :no_response_handler, action, success, data
      end
    end
  end

  def handle_command(data)
    action = data.delete('action')
    req_id = data.delete('req_id')
    if action.nil?
      log :message, '/!\ No action', data
    else
      command, operation = action.split('/', 2)
      handler = commands[command]
      if handler
        response = handler.handle(operation, data)
        response.merge! action: action, req_id: req_id
        log :message_response, response
        send(response)
      else
        log :message, :no_command_handler, action, data
      end
    end
  end

  def is_response?(data) 
    return data.has_key? 'success'
  end

  def loop
    EM.run do
      log "Connecting to #{remote_api}"
      @ws = Faye::WebSocket::Client.new(remote_api)

      @ws.on :open do |event|
        reset_back_off_delay!
        hashed_key = Base64.encode64(Digest::SHA1.digest(api_key + api_secret))
        credentials = { key: api_key, challenge: hashed_key}
        payload = {action: 'connection/auth', name: agent_name, credentials: credentials}
        log :open, payload
        send payload
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

  def reset_back_off_delay!
    @back_off_delay = 1
  end

  def back_off!
    sleep @back_off_delay
    @back_off_delay = [@back_off_delay * 2, 300].min
  end
    
end
