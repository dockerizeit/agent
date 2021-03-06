require 'spec_helper'
require 'agent'

describe Agent do
  Given!("A fake EM loop") { allow(Combi::Reactor).to receive :start }
  describe '#authorized callback' do
    Given(:agent) do
      allow_any_instance_of(Agent).to receive :check_connection_to_server
      a = Agent.new({})
      allow(a).to receive :start_forwarding_events
      allow(a).to receive :start_pinging
      a
    end
    Given(:token) { double('a token') }
    When('the callback is invoked with a token') { agent.authorized token }
    Then { agent.token === token }
    And  { expect(agent).to have_received :start_forwarding_events }
    And  { expect(agent).to have_received :start_pinging }
  end

  describe '#start_forwarding_events' do
    Given(:agent) do
      allow_any_instance_of(Agent).to receive :check_connection_to_server
      a = Agent.new({})
      allow(a).to receive :start_pinging
      a
    end
    Given(:events_reader) { double("Events::Reader", stop!: nil)}
    Given!('the event reader is stubbed') { allow(Events).to receive(:notify_on).and_return(events_reader) }
    When(:reader) { agent.start_forwarding_events }
    Then { expect(Events).to have_received(:notify_on) }
    context 'twice' do
      When { allow(reader).to receive :stop }
      When('start_forwarding_events is invoked twice') { agent.start_forwarding_events }
      Then { expect(reader).to have_received :stop! }
      And  { expect(Events).to have_received(:notify_on).twice }
    end
  end
end
