module Service
  module Tunnels

    def actions
      [:tunnels]
    end

    def start(tunnel_id:, container_id:, source_port:, ssh_port:, public_port:, **_unused_session)
      ssh_server = ENV['TUNNEL_SERVER']
      name = "tunnel-client-#{tunnel_id}"
      source_container = Docker::Container.get container_id
      container_remove name
      create_params = {
        'name' => name,
        'Image' => ENV['TUNNEL_CLIENT_IMAGE'],
        'Env' => [
          "SSH_KEY=#{$agent.tunnel_private_key}",
          "TUNNEL_SERVER=#{ssh_server}",
          "TUNNEL_PORT=#{ssh_port}",
          "SERVICE_HOST=#{source_container.json['NetworkSettings']['IPAddress']}",
          "SERVICE_PORT=#{source_port}",
          "TUNNEL_PUBLIC_PORT=#{public_port}"
        ]
      }
      container = Docker::Container.create create_params
      container.start
    end

    def stop(tunnel_id:, **_unused_session)
      container_stop "tunnel-client-#{tunnel_id}"
    end

    def remove(tunnel_id:, **_unused_session)
      container_remove "tunnel-client-#{tunnel_id}"
    end

    private

    def container_stop(name_or_id)
      begin
        container = Docker::Container.get name_or_id
        if container
          container.stop if container.info['State']['Running']
        end
      rescue Docker::Error::NotFoundError
      end
      container
    end

    def container_remove(name_or_id)
      container = container_stop name_or_id
      begin
        container.remove if container
      rescue Docker::Error::NotFoundError
      end
    end

  end

end
