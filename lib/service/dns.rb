require "net/http"

module Service
  module Dns

    def actions
      [:dns]
    end

    def register(message)
      params = {
        "Node" => message['node_name'],
        "Address" => message['ip_address']
      }
      consul_api(consul_ip, 'catalog/register', params)
    end

    def unregister(message)
      params = {
        "Node" => message['node_name']
      }
      consul_api(consul_ip, 'catalog/deregister', params)
    end

    private

    def consul_api(consul_ip_address, operation, params)
      consul_api_port = 8500
      req = Net::HTTP::Put.new("/v1/#{operation}")
      req.body = params.to_json
      Net::HTTP.new(consul_ip_address, consul_api_port).start do |http|
        response = http.request req
      end
    end

    def consul_ip
      return @consul_ip if @consul_ip
      consul_container = Docker::Container.get('dockerizeit_consul_server')
      @consul_ip = consul_container.json['NetworkSettings']['IPAddress']
    end

  end
end
