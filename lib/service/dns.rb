require 'dns'

module Service
  module Dns

    def actions
      [:dns]
    end

    def register(message)
      manager.register_node(message['node_name'], message['ip_address'])
    end

    def unregister(message)
      manager.unregister_node(message['node_name'])
    end

    def manager
      ::Dns::Manager.instance
    end
  end
end
