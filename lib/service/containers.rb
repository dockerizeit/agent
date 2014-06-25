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

    def index(message)
      include_stopped = message['include-stopped'] || true
      containers = Docker::Container.all(all: include_stopped)
      keys_to_hide = SECRETS_GREYLIST.dup
      keys_to_hide << message['env_keys_to_hide']
      keys_to_hide = keys_to_hide.flatten.compact.uniq
      response = filtered_containers(containers).map(&:json).map do |container|
        anonymize_container_info(container, keys_to_hide)
      end
      return response
    end

    def run(message)
      container = Docker::Container.create message['create_params']
      container.start message['start_params']
      container.json
    end

    def create(message)
      container = Docker::Container.create message['params']
      container.json
    end

    def start(message)
      container = Docker::Container.get(message['container_id'])
      container.start message['params']
      container.json
    end

    def restart(message)
      puts message.inspect
      container = Docker::Container.get(message['container_id'])
      container.restart
      container.json
    end

    def stop(message)
      container = Docker::Container.get(message['container_id'])
      container.stop
      container.json
    end

    def remove(message)
      container = Docker::Container.get(message['container_id'])
      container.remove
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
