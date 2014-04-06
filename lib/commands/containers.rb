class Commands::Containers < Commands::Base

  def index(data)
    Docker::Container.all(true)
  end
end
