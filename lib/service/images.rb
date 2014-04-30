module Service
  module Images
    def actions
      [:images]
    end

    def index(message)
      response = Docker::Image.all.map(&:json)
      response
    end

  end
end
