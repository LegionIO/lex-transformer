# frozen_string_literal: true

require 'spec_helper'
require 'legion/extensions/transformer/helpers/schema_validator'

RSpec.describe Legion::Extensions::Transformer::Helpers::SchemaValidator do
  describe '.validate' do
    context 'with nil schema' do
      it 'returns valid: true' do
        result = described_class.validate(schema: nil, data: { name: 'Alice' })
        expect(result).to eq({ valid: true })
      end
    end

    context 'with nil data' do
      it 'returns valid: false when required keys exist' do
        schema = { required_keys: [:name] }
        result = described_class.validate(schema: schema, data: nil)
        expect(result[:valid]).to be false
        expect(result[:errors]).to include(a_string_matching(/name/))
      end
    end

    context 'with empty schema' do
      it 'returns valid: true' do
        result = described_class.validate(schema: {}, data: { name: 'Alice' })
        expect(result).to eq({ valid: true })
      end
    end

    context 'with empty required_keys' do
      it 'returns valid: true' do
        schema = { required_keys: [] }
        result = described_class.validate(schema: schema, data: { name: 'Alice' })
        expect(result).to eq({ valid: true })
      end
    end

    context 'required_keys checks' do
      let(:schema) { { required_keys: %i[name email] } }

      it 'returns valid: true when all required keys are present' do
        result = described_class.validate(schema: schema, data: { name: 'Alice', email: 'alice@example.com' })
        expect(result).to eq({ valid: true })
      end

      it 'returns valid: false when a required key is missing' do
        result = described_class.validate(schema: schema, data: { name: 'Alice' })
        expect(result[:valid]).to be false
        expect(result[:errors]).to include(a_string_matching(/email/))
      end

      it 'returns multiple errors for multiple missing keys' do
        result = described_class.validate(schema: schema, data: {})
        expect(result[:valid]).to be false
        expect(result[:errors].length).to eq 2
      end

      it 'includes the missing key name in the error message' do
        result = described_class.validate(schema: schema, data: { email: 'x@y.com' })
        expect(result[:errors].first).to match(/name/)
      end
    end

    context 'type checks' do
      let(:schema) { { types: { name: String, age: Integer } } }

      it 'returns valid: true when types match' do
        result = described_class.validate(schema: schema, data: { name: 'Alice', age: 30 })
        expect(result).to eq({ valid: true })
      end

      it 'returns valid: false when a type does not match' do
        result = described_class.validate(schema: schema, data: { name: 'Alice', age: 'thirty' })
        expect(result[:valid]).to be false
        expect(result[:errors]).to include(a_string_matching(/age/))
      end

      it 'skips type check for keys not present in data' do
        result = described_class.validate(schema: schema, data: { name: 'Alice' })
        expect(result).to eq({ valid: true })
      end

      it 'reports the expected and actual type in the error message' do
        result = described_class.validate(schema: schema, data: { name: 123, age: 30 })
        expect(result[:errors].first).to match(/name/)
        expect(result[:errors].first).to match(/String/)
      end
    end

    context 'combined required_keys and types' do
      let(:schema) do
        {
          required_keys: %i[name email],
          types:         { name: String, email: String, age: Integer }
        }
      end

      it 'returns valid: true when all constraints pass' do
        data = { name: 'Alice', email: 'alice@example.com', age: 30 }
        result = described_class.validate(schema: schema, data: data)
        expect(result).to eq({ valid: true })
      end

      it 'accumulates errors from both required_keys and type checks' do
        data = { name: 42 }
        result = described_class.validate(schema: schema, data: data)
        expect(result[:valid]).to be false
        # missing :email (required) + wrong type for :name
        expect(result[:errors].length).to be >= 2
      end
    end
  end
end
