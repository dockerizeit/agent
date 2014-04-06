class Commands::Base
  def handle(operation, data)
    if self.respond_to?(operation)
      result = self.send(operation, data)
      {success: true, result: result.map(&:json) }
    else
      raise "Unknown operation #{operation}"
    end
  end
end
