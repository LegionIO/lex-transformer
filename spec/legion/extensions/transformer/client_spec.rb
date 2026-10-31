# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Legion::Extensions::Transformer::Client do
  subject(:client) { described_class.new }

  it 'renders trusted templates and returns only final chain output' do
    result = client.transform_chain(payload: { name: 'world' }, steps: [
                                      { transformation: '{"greeting":"hello <%= name %>"}' },
                                      { transformation: '{"message":"<%= greeting %>!"}' }
                                    ])
    expect(result).to include(success: true, result: { message: 'hello world!' })
  end

  it 'preserves business success fields without interpreting them as engine control results' do
    result = client.transform(transformation: '{"success":false,"reason":"business decision"}', payload: {})
    expect(result).to include(success: true, result: { success: false, reason: 'business decision' })
  end

  it 'does not permit ERB unless trusted engine execution is enabled' do
    Legion::Settings.with_overlay(extensions: { transformer: { allow_trusted_engines: false } }) do
      result = client.transform(transformation: '{"value":"<%= raise "executed" %>"}', payload: {})
      expect(result).to include(success: false, status: 'transformer.failed')
      expect(result[:message]).to include('trusted code')
    end
  end

  it 'honors the configured engine allowlist' do
    Legion::Settings.with_overlay(extensions: { transformer: { allowed_engines: { jsonpath: false } } }) do
      result = client.transform(transformation: 'item', engine: :jsonpath, payload: { item: { valid: true } })
      expect(result).to include(success: false)
      expect(result[:message]).to include('not allowed')
      expect(client.transform(transformation: '{"permitted":true}', payload: {})).to include(success: true)
    end
  end

  it 'rejects non-Boolean engine grants instead of treating truthy strings as permission' do
    Legion::Settings.with_overlay(extensions: { transformer: { allowed_engines: { static: 'false' } } }) do
      expect(client.transform(transformation: '{}', payload: {})).to include(success: false, error: 'ArgumentError')
    end
  end

  it 'never lets inherited symbol grants shadow a string-keyed denial' do
    Legion::Settings.with_overlay(extensions: { transformer: { allowed_engines: { 'jsonpath' => false } } }) do
      result = client.transform(transformation: 'item', engine: :jsonpath, payload: { item: { policy_bypass: true } })
      expect(result).to include(success: false, error: 'ArgumentError')
    end
  end

  it 'rejects malformed JSON rather than succeeding with unchanged text' do
    result = client.transform(transformation: '{broken', payload: {})
    expect(result).to include(success: false, error: 'Legion::JSON::ParseError')
  end

  it 'rejects scalar JSONPath results before they can become a no-op success' do
    result = client.transform(transformation: 'person.name', engine: :jsonpath, payload: { person: { name: 'Alice' } })
    expect(result).to include(success: false)
  end

  it 'rejects mixed fanout output' do
    result = client.transform(transformation: '[{"value":1},false]', payload: {})
    expect(result).to include(success: false)
  end

  it 'enforces the shared fanout bound before returning output' do
    Legion::Settings.with_overlay(task_execution: { execution: { max_fanout: 1 } }) do
      expect(client.transform(transformation: '[{},{}]', payload: {})).to include(success: false)
    end
  end

  it 'enforces string-keyed settings schema fields and supported type names' do
    schema = Legion::JSON.load('{"required_keys":["name"],"types":{"age":"integer"}}')
    missing = client.transform(transformation: '{"age":2}', schema: schema, payload: {})
    wrong_type = client.transform(transformation: '{"name":"Alice","age":"2"}', schema: schema, payload: {})
    valid = client.transform(transformation: '{"name":"Alice","age":2}', schema: schema, payload: {})
    expect(missing).to include(success: false, status: 'transformer.validation_failed')
    expect(wrong_type).to include(success: false, status: 'transformer.validation_failed')
    expect(valid).to include(success: true, result: { name: 'Alice', age: 2 })
  end

  it 'rejects unknown schema types instead of bypassing them' do
    result = client.transform(transformation: '{"item":1}', schema: { types: { item: 'Kernel' } }, payload: {})
    expect(result).to include(success: false)
    expect(result[:message]).to include('unsupported schema type')
  end

  it 'validates every object in a fanout schema' do
    result = client.transform(transformation: '[{"id":1},{"id":"bad"}]', schema: { types: { id: 'Integer' } }, payload: {})
    expect(result).to include(success: false, status: 'transformer.validation_failed')
    expect(result[:errors].first).to include('item 1')
  end

  context 'with helper-backed named definitions and the real Conditioner client' do
    let(:condition) { { all: [{ fact: 'allowed', operator: 'equal', value: true }] } }
    let(:definition) { { transformation: '{"accepted":true}', conditions: condition } }

    around do |example|
      Legion::Settings.with_overlay(extensions: { transformer: { definitions: { gated: definition } } }) { example.run }
    end

    it 'executes when the real condition returns valid true' do
      expect(client.transform(name: 'gated', payload: { allowed: true })).to include(success: true, result: { accepted: true })
    end

    it 'does not render when the condition returns valid false' do
      definition[:transformation] = '{"value":"<%= raise "executed" %>"}'
      expect(client.transform(name: 'gated', payload: { allowed: false })).to include(success: false, status: 'task.skipped')
    end

    it 'never fails open for a malformed condition' do
      condition[:all].first[:operator] = 'unsupported_operator'
      result = client.transform(name: 'gated', payload: { allowed: true })
      expect(result).to include(success: false, error: 'Legion::Extensions::Conditioner::ConfigurationError')
    end

    it 'fails clearly when the Conditioner dependency cannot load' do
      allow(client).to receive(:require).with('legion/extensions/conditioner/client').and_raise(LoadError, 'missing conditioner')
      expect(client.transform(name: 'gated', payload: { allowed: true })).to include(success: false, error: 'LoadError')
    end

    it 'does not reinterpret a missing definition as a direct transformation' do
      expect(client.transform(name: 'absent', payload: {})).to include(success: false)
    end
  end
end
