# frozen_string_literal: true

require 'spec_helper'
require 'timeout'
require 'legion/extensions/transformer/engines/llm'

RSpec.describe Legion::Extensions::Transformer::Engines::Llm do
  subject(:engine) { described_class.new }

  let(:provider) { Module.new }
  let(:response) { Struct.new(:content) }

  before do
    stub_const('Legion::LLM', provider)
    allow(provider).to receive(:started?).and_return(true)
  end

  it 'recovers from a transient timeout within the configured retry bound' do
    calls = 0
    allow(provider).to receive(:chat) do
      calls += 1
      raise Timeout::Error if calls == 1

      response.new('{"result":"ok"}')
    end
    expect(engine.render(template: 'Transform', payload: {}, max_retries: 1)).to eq('{"result":"ok"}')
    expect(calls).to eq(2)
  end

  it 'raises the parse error when invalid JSON exhausts retries' do
    allow(provider).to receive(:chat).and_return(response.new('not valid JSON'))
    expect { engine.render(template: 'Transform', payload: {}, max_retries: 0) }.to raise_error(Legion::JSON::ParseError)
  end

  it 'does not reuse raw JSON failure state from a different request' do
    allow(provider).to receive(:chat).and_return(response.new('invalid'))
    expect { engine.render(template: 'Transform', payload: {}, max_retries: 0) }.to raise_error(Legion::JSON::ParseError)
    allow(provider).to receive(:chat).and_raise(Timeout::Error)
    expect { engine.render(template: 'Transform', payload: {}, max_retries: 0) }.to raise_error(Timeout::Error)
  end

  it 'propagates permanent provider errors instead of retrying effects' do
    allow(provider).to receive(:chat).and_raise(RuntimeError, 'authentication failed')
    expect { engine.render(template: 'Transform', payload: {}, max_retries: 2) }.to raise_error(RuntimeError, 'authentication failed')
    expect(provider).to have_received(:chat).once
  end

  it 'parses structured responses through the same JSON boundary' do
    allow(provider).to receive(:structured).and_return(response.new("```json\n{\"summary\":\"ok\"}\n```"))
    result = engine.render(template: 'Summarize', payload: {}, structured: true, schema: { type: 'object' })
    expect(Legion::JSON.load(result)).to eq(summary: 'ok')
  end
end
