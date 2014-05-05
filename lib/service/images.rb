module Service
  module Images

    GREYLIST = [
      '<none>:<none>',
      '^dockerizeit/(.*)$'
    ]

    def actions
      [:images]
    end

    def index(message)
      result = Docker::Image.all(all: '1').map(&:info)
      result.reject{|image| image['RepoTags'].map{|tag| GREYLIST.map{|banned| tag.match(banned)}.any? }.any? }
    end

  end
end
