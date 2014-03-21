class Commands::Containers < Commands::Base
  

  def index(data)
    containers = Docker::Container.all(true)
    response = {success: true, result: containers.map(&:json) }
  end
  
end
