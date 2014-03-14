class Commands::Containers < Commands::Base
  

  def index(data)
    response = {success: true, result: ["dummy result"]}
  end

  def rm(data)
    response = {success: false, message: "Not found"}
  end
end
