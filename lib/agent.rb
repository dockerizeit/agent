require 'json'
require 'digest/sha1'
require 'docker'

require 'commands'
require 'responses'

require 'combi'

class Agent
  ## ATTR READERS
  [:api_key, :api_secret, :agent_name, :remote_api, :keep_alive_period].each do |m|
    define_method m do
      @config[m]
    end
  end
  ## END ATTR READERS

  def initialize(config)
    @config = config
    init_docker
  end

  def start!
    @bus = Combi::ServiceBus.for(:web_socket, remote_api: remote_api, handler: self)
    bus.start!
  end

  def on_open
    hashed_key = Base64.encode64(Digest::SHA1.digest(api_key + api_secret))
    credentials = { key: api_key, challenge: hashed_key}
    payload = {action: 'connection/auth', name: agent_name, credentials: credentials}
    log :open, payload
    bus.send payload.to_json
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
        bus.send(response.to_json)
      else
        log :message, :no_command_handler, action, data
      end
    end
  end

  def log(*arguments)
    p [Time.now, api_key, arguments]
  end

  def send(payload)
    bus.send(payload.to_json)
  end

  protected

  def bus
    @bus
  end

  def init_docker
    Docker.url = "unix:///var/run/docker.sock" unless ENV['DOCKER_HOST']
    puts "Using DOCKER_URL #{Docker.url}"
    puts "Versions: #{Docker.version.inspect}"
    puts "Info: #{Docker.info.inspect}"
  end

  def commands
    @commands ||= {
      'containers' => Commands::Containers.new
    }
  end

  def responses
    @responses ||= {
      'connection' => Responses::Connection.new(self)
    }
  end

end
