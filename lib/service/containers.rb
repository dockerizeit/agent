module Service
  module Containers

    def actions
      [:containers]
    end

    GREYLIST = [
      '^dockerizeit/agent\:(.*)$'
    ]

    def index(message)
      containers = Docker::Container.all(true)
      response = containers.reject{|container| GREYLIST.map{|banned| container.info['Image'].match(banned)}.any? }
      return response.map(&:json)
    end

    def run(message)
      container = Docker::Container.create('Image' => message['image'], 'Ports' => message['ports'])
      container.start
      container.json
    end

    def stop(message)
      container = Docker::Container.get(message['container_id'])
      container.stop
      container.json
    end

  end
end
