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

  end
end
