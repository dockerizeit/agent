$: << './lib'

require 'agent'

CONFIG = {
  api_key: ENV['KEY'] || ARGV[0],
  api_secret: ENV['SECRET'] || ARGV[1],
  agent_name: ENV['NAME'] || ARGV[2],
  remote_api: ENV['REMOTE_API'] || 'ws://192.168.1.39:9000/',
  keep_alive_period: [(ENV['KEEPALIVE'] || 10).to_i, 1].max
}

Agent.new(CONFIG).start!
