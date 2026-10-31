# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'LLM client output boundary' do
  let(:client) { Legion::Extensions::Transformer::Client.new }
  let(:provider) { Module.new }

  before do
    stub_const('Legion::LLM', provider)
    allow(provider).to receive(:started?).and_return(true)
  end

  it 'rejects scalar provider JSON instead of succeeding without a dispatchable payload' do
    allow(provider).to receive(:chat).and_return('42')
    result = client.transform(transformation: 'Transform', engine: :llm, payload: {})
    expect(result).to include(success: false, status: 'transformer.failed')
  end

  it 'turns an actual exhausted engine exception into a client failure' do
    allow(provider).to receive(:chat).and_raise(Timeout::Error, 'provider unavailable')
    result = client.transform(transformation: 'Transform', engine: :llm, engine_options: { max_retries: 0 }, payload: {})
    expect(result).to include(success: false, status: 'transformer.failed', error: 'Timeout::Error')
  end

  it 'stops a mixed-engine chain when provider output fails the schema' do
    allow(provider).to receive(:chat).and_return('{"name":"Alice"}')
    result = client.transform_chain(payload: {}, steps: [
                                      { transformation: 'Extract', engine: :llm, schema: { required_keys: ['email'] } },
                                      { transformation: '{"value":"<%= raise "executed" %>"}' }
                                    ])
    expect(result).to include(success: false, status: 'transformer.validation_failed')
  end
end
