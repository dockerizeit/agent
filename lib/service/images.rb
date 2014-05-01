module Service
  module Images
    def actions
      [:images]
    end

    def index(message)
      Docker::Image.all(all: '1').map(&:info)
    end

  end
end
