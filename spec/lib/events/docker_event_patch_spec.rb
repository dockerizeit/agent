require 'spec_helper'
require 'docker'
require 'events/docker_event_patch'

describe 'Docker::Event' do
  Given(:an_event) { Docker::Event.new('status', 'id', 'from', 'time') }
  When(:serialized) { an_event.json }
  Then { serialized == { "status" => "status", "id" => "id", "from" => "from", "time" => "time" } }
end
