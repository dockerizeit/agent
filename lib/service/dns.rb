require 'dns'

module Service
  module Dns

    def actions
      [:dns]
    end

    def register(node_name:, ip_address:)
      manager.register_node node_name, ip_addres
    end

    def unregister(node_name:)
      manager.unregister_node node_name
    end

    def manager
      ::Dns::Manager.instance
    end
  end
end
