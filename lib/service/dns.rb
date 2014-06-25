require 'dns'

module Service
  module Dns

    def actions
      [:dns]
    end

    def register(node_name:, ip_address:, **_unused_session)
      manager.register_node node_name, ip_address
    end

    def unregister(node_name:, **_unused_session)
      manager.unregister_node node_name
    end

    def manager
      ::Dns::Manager.instance
    end
  end
end
