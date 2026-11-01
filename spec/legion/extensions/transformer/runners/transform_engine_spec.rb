# frozen_string_literal: true

require 'spec_helper'
require 'legion/extensions/transformer/runners/transform'
require 'legion/transport/exchanges/task'

RSpec.describe 'Transformer stage publication' do
  subject(:runner) do
    stub_const('Legion::Extensions::Transformer::Runners::TransformHarness', Class.new do
      include Legion::Settings::Helper
      include Legion::Extensions::Transformer::Runners::Transform
    end).new
  end

  let(:target) { { function: 'deliver', runner_routing_key: 'test.receiver.deliver', runner_class: 'Test::Receiver' } }
  let(:received) { [] }

  before do
    Legion::Transport::Connection.setup
    @channel = Legion::Transport::Connection.session.create_channel
    @queue = @channel.queue_declare_without_recording_topology('transformer-test-target')
    @queue.bind('task', routing_key: 'test.receiver.deliver')
    @queue.subscribe(manual_ack: false) { |_delivery, _properties, body| received << Legion::JSON.load(body) }
  end

  after do
    @channel.close
    Legion::Transport::Local.reset!
  end

  around do |example|
    Legion::Settings.with_overlay(data: { connected: false }, transport: { messages: { encrypt: false } }) { example.run }
  end

  it 'publishes only the final chain output through the real transport' do
    result = runner.transform(steps: [{ transformation: '{"value":1}' }, { transformation: '{"final":<%= value + 1 %>}' }], **target)
    expect(result).to include(success: true, result: { final: 2 }, durable: false)
    expect(received.map { |message| message[:args] }).to eq([{ final: 2 }])
  end

  it 'does not publish malformed JSON or scalar output' do
    expect(runner.transform(transformation: '{broken', **target)).to include(success: false)
    expect(runner.transform(transformation: '42', **target)).to include(success: false)
    expect(received).to be_empty
  end

  it 'executes named conditions with the real Conditioner client and never fails open' do
    definition = { transformation: '{"accepted":true}', conditions: { all: [{ fact: 'allowed', operator: 'equal', value: true }] } }
    Legion::Settings.with_overlay(extensions: { transformer: { definitions: { gate: definition } } }) do
      expect(runner.transform(name: 'gate', args: { allowed: true }, **target)).to include(success: true)
      expect(runner.transform(name: 'gate', args: { allowed: false }, **target)).to include(success: false)
      definition[:conditions][:all].first[:operator] = 'invalid'
      expect(runner.transform(name: 'gate', args: { allowed: true }, **target)).to include(success: false)
    end
    expect(received.map { |message| message[:args] }).to eq([{ accepted: true }])
  end

  it 'raises a rejected publication rather than reporting a successful handoff' do
    @channel.close
    Legion::Transport::Local.reset!
    expect { runner.transform(transformation: '{}', **target) }.to raise_error(Legion::Transport::PublishRejected)
  end
end
