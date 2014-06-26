require 'net/http'
require 'eventmachine'

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

  private

  def initialize(options)
    @options = options
    @options[:enabled] ||= true
    start
    @ready = EM::DefaultDeferrable.new
  end

  def start
    EM::next_tick do
      if options[:enabled]
        image_name = options[:container_image]
        create_params = {
          'name'  => options[:container_name],
          'Image' => image_name,
          'Hostname' => 'consul-main-node',
          'Cmd'   => ['-server', '-bootstrap', '-log-level=trace']
        }
        start_params = {
          'PortBindings' => {'53/udp' => [{HostIp: '0.0.0.0', HostPort: '53'}]}
        }
        begin
          Docker::Image.create fromImage: image_name
          container = Docker::Container.create create_params
          container.start start_params
          ready.succeed
        rescue => e
          puts e.inspect
          puts "Cannot start the dns manager"
        end
      end
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
    return @consul_ip if @consul_ip
    consul_container = Docker::Container.get(options[:container_name])
    @consul_ip = consul_container.json['NetworkSettings']['IPAddress']
  end

  def consul_api_port
    8500
  end

end
