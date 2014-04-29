module Service
  module Containers

    def actions
      [:containers]
    end

    def index(message)
      containers = Docker::Container.all(true)
      $bus.request 'containers', 'info', kind: 'index', result: containers.map(&:json)
      no_response
    end

    def run(message)
      container = Docker::Container.create('Image' => message['image'], 'Ports' => message['ports'])
      container.start
      container.json
    end

  end
end
