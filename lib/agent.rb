require 'digest/sha1'
require 'docker'

require 'combi'
require 'combi/reactor'

require 'service/connection'
require 'service/containers'

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
    Combi::Reactor.start
    init_docker
    init_buses
  end

  def init_buses
    $bus = Combi::ServiceBus.for(:web_socket, remote_api: remote_api, handler: self)
    $bus.start!
    $bus.add_service(Service::Connection, context: {agent: self})
    $bus.add_service(Service::Containers)
  end

  def start!
    Combi::Reactor.join_thread
  end

  def on_open
    hashed_key = Base64.encode64(Digest::SHA1.digest(api_key + api_secret))
    credentials = { key: api_key, challenge: hashed_key}
    message = {name: agent_name, credentials: credentials}
    $bus.request('connection', 'auth', message)
    log :open, agent_name, credentials
  end

  def start_pinging
    stop_pinging
    @ping_timer = EM.add_periodic_timer keep_alive_period do
      message = {at: Time.now.utc}
      $bus.request('connection', 'ping', message)
      log :ping, message
    end
  end

  def stop_pinging
    return unless @ping_timer
    EM::cancel_timer @ping_timer
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

end
