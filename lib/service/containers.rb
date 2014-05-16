module Service
  module Containers

    def actions
      [:containers]
    end

    GREYLIST = [
      '^dockerizeit/agent\:(.*)$'
    ]

    HIDDEN_SECRET = "*****"
    SECRETS_GREYLIST = [
      'PASS',
      'SECRET',
      'TOKEN'
    ]

    def index(message)
      containers = Docker::Container.all(true)
      keys_to_hide = SECRETS_GREYLIST.dup
      keys_to_hide << message['env_keys_to_hide']
      keys_to_hide = keys_to_hide.flatten.compact.uniq
      response = filtered_containers(containers).map(&:json).map do |container|
        anonymize_container_info(container, keys_to_hide)
      end
      return response
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

    private

    def filtered_containers(containers)
      containers.reject{|container| GREYLIST.map{|banned| container.info['Image'].match(banned)}.any? }
    end

    def anonymize_container_info(container, keys_to_hide)
      container['Config']['Env'] = container['Config']['Env'].map do |env_config|
        key, value = env_config.split('=')
        keys_to_hide.each do |secret_match|
          value = HIDDEN_SECRET if key.upcase.match(secret_match)
        end
        "#{key}=#{value}"
      end
      container
    end

  end
end
