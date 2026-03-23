# frozen_string_literal: true

require 'spec_helper'
require 'tilt'
require 'json'

require 'legion/extensions/transformer/runners/transform'

RSpec.describe Legion::Extensions::Transformer::Runners::Transform, '#transform with schema' do
  let(:test_class) do
    klass = Class.new do
      include Legion::Extensions::Transformer::Runners::Transform

      def from_json(str)
        JSON.parse(str, symbolize_names: true)
      end

      def dispatch_transformed(_payload); end

      def generate_task_log(**_opts); end
    end
    klass.new
  end

  context 'without schema' do
    it 'returns success: true (existing behaviour unchanged)' do
      result = test_class.transform(transformation: '{"key":"value"}')
      expect(result[:success]).to be true
      expect(result[:args]).to eq({ key: 'value' })
    end
  end

  context 'with schema that passes' do
    it 'returns success: true' do
      schema = { required_keys: [:key] }
      result = test_class.transform(transformation: '{"key":"value"}', schema: schema)
      expect(result[:success]).to be true
    end
  end

  context 'with schema that fails' do
    it 'returns success: false with validation_failed status' do
      schema = { required_keys: [:missing] }
      result = test_class.transform(transformation: '{"key":"value"}', schema: schema)
      expect(result[:success]).to be false
      expect(result[:status]).to eq 'transformer.validation_failed'
      expect(result[:errors]).to be_an(Array)
      expect(result[:errors].first).to match(/missing/)
    end

    it 'does not dispatch when validation fails' do
      schema = { required_keys: [:missing] }
      expect(test_class).not_to receive(:dispatch_transformed)
      test_class.transform(transformation: '{"key":"value"}', schema: schema)
    end
  end

  context 'with type-checking schema that fails' do
    it 'returns validation errors' do
      schema = { types: { key: Integer } }
      result = test_class.transform(transformation: '{"key":"not_an_int"}', schema: schema)
      expect(result[:success]).to be false
      expect(result[:errors].first).to match(/key/)
    end
  end
end
