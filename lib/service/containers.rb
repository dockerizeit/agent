module Service
  module Containers

    def actions
      [:containers]
    end

    GREYLIST = [
      '^dockerizeit/agent\:(.*)$',
      '^dockerizeit/consul\:(.*)$'
    ]

    HIDDEN_SECRET = "*****"
    SECRETS_GREYLIST = [
      'PASS',
      'SECRET',
      'TOKEN'
    ]

    def index(include_stopped: true, env_keys_to_hide: [], req_id: nil, **_unused_session)
      containers = Docker::Container.all(all: include_stopped)
      keys_to_hide = SECRETS_GREYLIST.dup
      keys_to_hide += Array(env_keys_to_hide)
      keys_to_hide = keys_to_hide.compact.uniq
      response = filtered_containers(containers).map(&:json).map do |container|
        anonymize_container_info(container, keys_to_hide)
      end
      return response
    end

    def run(create_params:, start_params:, **_unused_session)
      container = Docker::Container.create create_params
      container.start start_params
      container.json
    end

    def create(params:, **_unused_session)
      container = Docker::Container.create params
      container.json
    end

    def start(container_id:, params: {}, **_unused_session)
      container = Docker::Container.get(container_id)
      container.start params
      container.json
    end

    def restart(container_id:, **_unused_session)
      container = Docker::Container.get container_id
      container.restart
      container.json
    end

    def stop(container_id:, **_unused_session)
      container = Docker::Container.get container_id
      container.stop
      container.json
    end

    def remove(container_id:, **_unused_session)
      container = Docker::Container.get container_id
      container.remove
      {}
    end

    def pause(container_id:, **_unused_session)
      container = Docker::Container.get container_id
      raise "TODO: not yet implemented in swipely/docker-api: https://github.com/swipely/docker-api/issues/151"
      container.pause
      {}
    end

    def unpause(container_id:, **_unused_session)
      container = Docker::Container.get container_id
      raise "TODO: not yet implemented in swipely/docker-api: https://github.com/swipely/docker-api/issues/151"
      container.unpause
      {}
    end

    private

    def filtered_containers(containers)
      containers.reject{|container| GREYLIST.map{|banned| container.info['Image'].match(banned)}.any? }
    end

    def anonymize_container_info(container, keys_to_hide)
      container['Config']['Env'] = container['Config']['Env'].map do |env_config|
        key, value = env_config.split('=')
        keys_to_hide.each do |secret_match|
          value = HIDDEN_SECRET if key.to_s.upcase.match(secret_match)
        end
        "#{key}=#{value}"
      end
      container
    end
  end
end
