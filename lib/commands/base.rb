class Commands::Base
  def handle(operation, data)
    if self.respond_to?(operation)
      self.send(operation, data)
    else
      raise "Unknown operation #{operation}"
    end
  end
end
