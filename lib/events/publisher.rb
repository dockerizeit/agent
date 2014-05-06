require_relative 'docker_event_patch'

class Events::Publisher
  def initialize(bus)
    @bus = bus
  end

  # Receives Docker::Event objects and does something
  #
  # Example data:
  #     {"status":"create","id":"dfdf82bd3881","from":"base:latest","time":1374067924}
  #     {"status":"start","id":"dfdf82bd3881","from":"base:latest","time":1374067924}
  #     {"status":"stop","id":"dfdf82bd3881","from":"base:latest","time":1374067966}
  #     {"status":"destroy","id":"dfdf82bd3881","from":"base:latest","time":1374067970}
  def handle_event(event)
    puts "\t#{event}"
    # @amuino: Need a new thread to avoid loosing events
    #          For instance, running a fast command like
    #          "docker run ubuntu ls -la" and handling the events on the
    #          same thread causes the start event to be missed.
    Thread.new do
      case event.status
      when 'create' then handle_create(event)
      when 'start' then handle_start(event)
      when 'die'  then handle_die(event)
      when 'stop'  then handle_stop(event)
      else
        puts "Unknown event: #{event.inspect}"
      end
    end
  end

  # Event fired when creating a new container.
  # For instance: docker run IMAGE COMMAND
  def handle_create(event)
    @bus.request 'containers', 'created', event: event.json, container: Docker::Container.get(event.id).json
  end

  # Event fired when starting an existing container
  # For instance; docker start STOPPED_CONTAINER
  # Also, right after "create" on: docker run IMAGE COMMAND
  def handle_start(event)
    @bus.request 'containers', 'started', event: event.json, container: Docker::Container.get(event.id).json
  end

  # Event fired when execution of the container terminates
  # For instance, after create and start on: docker run IMAGE ls
  # Also, when stopping a container: docker stop RUNNING_CONTAINER
  def handle_die(event)
    @bus.request 'containers', 'died', event: event.json, container: Docker::Container.get(event.id).json
  end

  # Event fired when execution of the container is stopped by the user
  # For instance, after die on: docker stop RUNNING_CONTAINER
  def handle_stop(event)
    @bus.request 'containers', 'stopped', event: event.json, container: Docker::Container.get(event.id).json
  end
end
