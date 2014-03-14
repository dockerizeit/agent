class Responses::Base
  attr_reader :agent
  
  def initialize(agent)
    @agent = agent
  end

  def handle(operation, success, data)
    if self.respond_to?(operation)
      self.send(operation, success, data)
    else
      raise "Unhandled response to operation #{operation}"
    end
  end
end
