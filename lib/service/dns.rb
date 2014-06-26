require 'dns'

module Service
  module Dns

    def actions
      [:dns]
    end

    def register(dns_name:, ip_address:, **_unused_session)
      manager.register_node dns_name, ip_address
    end

    def unregister(dns_name:, **_unused_session)
      manager.unregister_node dns_name

    def reset(nodes_info:, **_unused_session)
      manager.reset_nodes nodes_info
    end

    def manager
      ::Dns::Manager.instance
    end
  end
end
