require 'digest/sha1'
require 'docker'

require 'combi'
require 'combi/reactor'

require 'service/containers'
require 'service/images'
require 'service/dns'
require 'events'
require 'dns'
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
    if init_docker
      start_dns_server
      init_buses
      check_connection_to_server
    else
      stop!
    end
  end

  def init_buses
    $bus = Combi::ServiceBus.for(:web_socket, remote_api: remote_api, handler: self)
    $bus.start!
    $bus.add_service(Service::Containers)
    $bus.add_service(Service::Images)
    $bus.add_service(Service::Dns)
  end

  def start!
    @reader.join_thread if @reader
    Combi::Reactor.join_thread
  end

  def stop!
    @reader.stop! if @reader
    stop_pinging
    disconnect_from_server
    EM::stop
  end


  def on_open
    change_connection_status connected: true
    @delay_until_next_connection = 0 # reset the delay for reconnections after a good connection
    @token = nil
    hashed_key = Base64.encode64(Digest::SHA1.digest(api_key + api_secret))
    credentials = { key: api_key, challenge: hashed_key}
    message = {
      name: agent_name,
      credentials: credentials,
      agent: {
        version: Agent::VERSION
      },
      host: {
        docker: {
          version: Docker.version,
          info: Docker.info
        }
      }
    }
    response = $bus.request('connection', 'auth', message)
    response.callback do |message|
      authorized(message[:token])
    end
    response.errback do |message|
      log :auth, :fail, message
      if message[:error].is_a? Hash
        stop! if message[:error][:status] == 401 # unauthorized
      end
    end
    log :open, agent_name, credentials
  end

  def on_close
    change_connection_status connected: false
    stop_pinging
  end

  def change_connection_status(connected:)
    return if @connected == connected
    @connected = connected
    log :connection_status, @connected ? "ON" : "OFF"
  end

  def check_connection_to_server
    return unless @check_connection_timer.nil?
    @check_connection_timer = EM.add_periodic_timer CHECK_CONNECTION_INTERVAL do
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

  def start_dns_server
    Dns::Manager.start({
      enabled: ENV['DNS_MANAGER_ENABLED'] != 'no',
      container_image: ENV['DNS_MANAGER_IMAGE'],
      container_name: ENV['DNS_MANAGER_NAME']
    })
  end

  def log(*arguments)
    p [Time.now, api_key, arguments]
  end

  protected

  def init_docker
    Docker.url = "unix:///var/run/docker.sock" unless ENV['DOCKER_HOST']
    log "Using DOCKER_URL #{Docker.url}"
    log "Versions: #{Docker.version.inspect}"
    log "Info: #{Docker.info.inspect}"
    true
  rescue => e
    log "Error connecting to docker", e.message
    false
  end

end
