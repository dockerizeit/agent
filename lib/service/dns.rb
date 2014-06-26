require 'dns'

module Service
  module Dns

    def actions
      [:dns]
    end

    def register(message)
      manager.register_node(message['dns_name'], message['ip_address'])
    end

    def unregister(message)
      manager.unregister_node(message['dns_name'])
    end

    def reset(message)
      manager.reset_nodes(message['nodes_info'])
    end

    def manager
      ::Dns::Manager.instance
    end
  end
end
