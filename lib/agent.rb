require 'digest/sha1'
require 'docker'

require 'combi'
require 'combi/reactor'

require 'service/connection'
require 'service/containers'
require 'service/images'
require 'events'
require 'version'

class Agent
  include Version

  CHECK_CONNECTION_INTERVAL = 3

  attr_reader :token
  ## ATTR READERS
  [:api_key, :api_secret, :agent_name, :remote_api, :keep_alive_period].each do |m|
    define_method m do
      @config[m]
    end
  end
  ## END ATTR READERS

  def initialize(config)
    @config = config
    @delay_until_next_connection = 0
    Combi::Reactor.start
    init_docker
    init_buses
    check_connection_to_server
  end

  def init_buses
    $bus = Combi::ServiceBus.for(:web_socket, remote_api: remote_api, handler: self)
    $bus.start!
    $bus.add_service(Service::Connection, context: {agent: self})
    $bus.add_service(Service::Containers)
    $bus.add_service(Service::Images)
  end

  def start!
    @reader.join_thread if @reader
    Combi::Reactor.join_thread
  end

  def on_open
    @connected = true
    @delay_until_next_connection = 0 # reset the delay for reconnections after a good connection
    @token = nil
    hashed_key = Base64.encode64(Digest::SHA1.digest(api_key + api_secret))
    credentials = { key: api_key, challenge: hashed_key}
    message = {name: agent_name, credentials: credentials}
    $bus.request('connection', 'auth', message)
    log :open, agent_name, credentials
  end

  def on_close
    @connected = false
  end

  def check_connection_to_server
    return unless @check_connection_timer.nil?
    @check_connection_timer = EM.add_periodic_timer CHECK_CONNECTION_INTERVAL do
      log :connection_status, @connected ? "ON" : "OFF"
      if !@connected && @connection_timer.nil?
        next_delay = delay_until_next_connection
        log :next_connection, next_delay
        @connection_timer = EM.add_timer next_delay do
          $bus.start!
          log :connecting
          @connection_timer = nil
        end
      end
    end
  end

  def disconnect_from_server
    return unless @check_connection_timer
    EM::cancel_timer @check_connection_timer
    EM::cancel_timer @connection_timer unless @connection_timer.nil?
  end

  def delay_until_next_connection
    @delay_until_next_connection = [1+@delay_until_next_connection*2, 30].min
    rand*@delay_until_next_connection
  end

  def authorized(token)
    @token = token
    start_forwarding_events
    start_pinging
  end

  def start_forwarding_events
    @reader.stop! if @reader
    @reader = Events::notify_on $bus
  end

  def start_pinging
    stop_pinging
    @ping_timer = EM.add_periodic_timer keep_alive_period do
      message = {
        at: Time.now.utc,
        token: token
      }
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
