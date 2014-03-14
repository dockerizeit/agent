require 'commands'
require 'rspec-given'

describe Commands::Base do
  Given(:a_command) { Class.new(Commands::Base).new }

  context '#handle(operation, data)' do
    Given(:operation) { :operation }
    Given(:data) { double('some data') }

    context 'calls the operation with data' do
      Given("The comand implements the operation") do
        a_command.stub(operation)
      end
      When("invoked") { a_command.handle operation, data }
      Then do
        expect(a_command).to have_received(operation).with(data)
      end
    end
    context 'raises if the operation does not exist' do
      When(:result)  { a_command.handle operation, data }
      Then { expect(result).to have_failed }
    end
  end
end
