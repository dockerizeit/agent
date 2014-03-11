class Commands::Containers
  def handle(operation, data)
    if self.respond_to?(operation)
      self.send(operation, data)
    else
      raise "Unknown operation #{operation}"
    end
  end

  def index(data)
    response = {success: true, result: ["dummy result"]}
  end

  def rm(data)
    response = {success: false, message: "Not found"}
  end
end
