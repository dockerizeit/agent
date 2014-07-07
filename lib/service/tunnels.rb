module Service
  module Tunnels

    def actions
      [:tunnels]
    end

    def start(tunnel_id:, container_id:, source_port:, ssh_port:, **_unused_session)
      ssh_server = ENV['TUNNEL_SERVER']
      name = "tunnel-client-#{tunnel_id}"
      source_container = Docker::Container.get container_id
      begin
        container = Docker::Container.get name
        if container
          container.stop if container.info['State']['Running']
          container.remove
        end
      rescue Docker::Error::NotFoundError
      end
      create_params = {
        'name' => name,
        'Image' => ENV['TUNNEL_CLIENT_IMAGE'],
        'Env' => [
          "SSH_KEY=#{$agent.tunnel_private_key}",
          "TUNNEL_SERVER=#{ssh_server}",
          "TUNNEL_PORT=#{ssh_port}",
          "SERVICE_HOST=#{source_container.json['NetworkSettings']['IPAddress']}",
          "SERVICE_PORT=#{source_port}"
        ]
      }
      container = Docker::Container.create create_params
      container.start
    end

  end
end
