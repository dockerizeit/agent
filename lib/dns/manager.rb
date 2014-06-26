require 'net/http'
require 'eventmachine'
require 'em-http'

class Dns::Manager

  attr_reader :options, :ready

  def self.start(options = {})
    @@instance = new(options)
  end

  def self.instance
    @@instance ||= start
  end

  def register_node(name, ip)
    ready.callback {
      consul_api('catalog/register', Node: name, Address: ip)
    }
  end

  def unregister_node(name)
    ready.callback {
      consul_api('catalog/deregister', Node: name)
    }
  end

  def reset_nodes(nodes_list)
    ready.callback {
      response = consul_api(:get, 'catalog/nodes')
      current_nodes = (JSON.parse(response.body) || []).map{|n| n['Node']}
      current_nodes = current_nodes.reject{|n| n == options[:consul_node_name]}
      expired_nodes = current_nodes - nodes_list.map{|n| n['dns_name']}
      expired_nodes.each do |expired|
        unregister_node(expired)
      end
      nodes_list.each do |node_info|
        register_node(node_info['dns_name'], node_info['ip_address'])
      end
    }
  end

  private

  def initialize(options)
    @options = options
    @options[:enabled] ||= true
    @options[:consul_node_name] ||= 'consul-main-node'
    start
    @ready = EM::DefaultDeferrable.new
  end

  def start
    EM::next_tick do
      if options[:enabled]
        begin
          container = Docker::Container.get options[:container_name]
          if container.info['State']['Running']
            warm_up
          else
            container.remove
            launch_container
          end
        rescue Docker::Error::NotFoundError
          launch_container
        end
      end
    end
  end

  def launch_container
    image_name = options[:container_image]
    create_params = {
      'name'  => options[:container_name],
      'Image' => image_name,
      'Hostname' => options[:consul_node_name],
      'Cmd'   => ['-server', '-bootstrap', '-log-level=trace']
    }
    start_params = {
      'PortBindings' => {'53/udp' => [{HostIp: '0.0.0.0', HostPort: '53'}]}
    }
    begin
      Docker::Image.create fromImage: image_name
      container = Docker::Container.create create_params
      container.start start_params
      start
    rescue => e
      puts e.inspect
      puts "Cannot start the dns manager"
    end
  end

  def warm_up
    http = EventMachine::HttpRequest.new("http://#{consul_ip_address}:#{consul_api_port}/v1/catalog/nodes").get
    http.callback do |info|
      if info.response_header.status == 200
        ready.succeed
      else
        EM::add_timer(1) { warm_up }
      end
    end
    http.errback do
      EM::add_timer(1) { warm_up }
    end
  end

  def consul_api(operation, params)
    req = Net::HTTP::Put.new("/v1/#{operation}")
    req.body = params.to_json
    Net::HTTP.new(consul_ip_address, consul_api_port).start do |http|
      response = http.request req
    end
  end

  def consul_ip_address
    return @consul_ip if !@consul_ip.nil? && !@consul_ip.empty?
    consul_container = Docker::Container.get(options[:container_name])
    @consul_ip = consul_container.json['NetworkSettings']['IPAddress']
  end

  def consul_api_port
    8500
  end

end
