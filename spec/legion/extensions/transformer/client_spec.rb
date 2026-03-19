# frozen_string_literal: true

require 'spec_helper'
require 'tilt'
require 'json'

require 'legion/extensions/transformer/client'

RSpec.describe Legion::Extensions::Transformer::Client do
  subject(:client) { described_class.new }

  describe '#transform' do
    context 'with static engine (auto-detected)' do
      it 'renders a static JSON template' do
        result = client.transform(
          transformation: '{"greeting":"hello"}',
          payload:        { name: 'test' }
        )
        expect(result[:success]).to be true
        expect(result[:result]).to eq(greeting: 'hello')
      end
    end

    context 'with ERB engine (auto-detected)' do
      it 'renders an ERB template with payload variables' do
        result = client.transform(
          transformation: '{"greeting":"hello <%= name %>"}',
          payload:        { name: 'world' }
        )
        expect(result[:success]).to be true
        expect(result[:result]).to eq(greeting: 'hello world')
      end
    end

    context 'with explicit static engine' do
      it 'uses the static engine when specified' do
        result = client.transform(
          transformation: '{"key":"value"}',
          payload:        {},
          engine:         :static
        )
        expect(result[:success]).to be true
        expect(result[:result]).to eq(key: 'value')
      end
    end

    context 'with explicit ERB engine' do
      it 'renders ERB when engine is specified' do
        result = client.transform(
          transformation: '{"val":"<%= num %>"}',
          payload:        { num: 42 },
          engine:         :erb
        )
        expect(result[:success]).to be true
        expect(result[:result]).to eq(val: '42')
      end
    end

    context 'with liquid engine' do
      it 'renders a liquid template' do
        result = client.transform(
          transformation: '{"greeting":"hello {{ name }}"}',
          payload:        { name: 'liquid' },
          engine:         :liquid
        )
        expect(result[:success]).to be true
        expect(result[:result]).to eq(greeting: 'hello liquid')
      end
    end

    context 'with jsonpath engine' do
      it 'extracts a nested value by path' do
        result = client.transform(
          transformation: 'user.name',
          payload:        { user: { name: 'Alice' } },
          engine:         :jsonpath
        )
        expect(result[:success]).to be true
        expect(result[:result]).to eq('Alice')
      end

      it 'extracts a numeric value by path' do
        result = client.transform(
          transformation: 'response.code',
          payload:        { response: { code: 200 } },
          engine:         :jsonpath
        )
        expect(result[:success]).to be true
        expect(result[:result]).to eq(200)
      end
    end

    context 'with schema validation' do
      it 'returns success false when required keys are missing' do
        result = client.transform(
          transformation: '{"name":"test"}',
          payload:        {},
          schema:         { required_keys: %i[name email] }
        )
        expect(result[:success]).to be false
        expect(result[:status]).to eq('transformer.validation_failed')
        expect(result[:errors]).to include(a_string_matching(/email/))
      end

      it 'returns success true when required keys are present' do
        result = client.transform(
          transformation: '{"name":"test","email":"t@t.com"}',
          payload:        {},
          schema:         { required_keys: %i[name email] }
        )
        expect(result[:success]).to be true
        expect(result[:result]).to eq(name: 'test', email: 't@t.com')
      end

      it 'returns success true when no schema is provided' do
        result = client.transform(
          transformation: '{"key":"val"}',
          payload:        {}
        )
        expect(result[:success]).to be true
      end

      it 'returns validation errors for type mismatches' do
        result = client.transform(
          transformation: '{"count":"not_a_number"}',
          payload:        {},
          schema:         { types: { count: Integer } }
        )
        expect(result[:success]).to be false
        expect(result[:errors].first).to match(/count/)
      end
    end
  end

  describe '#transform_chain' do
    context 'with a single step' do
      it 'returns success true with the rendered result' do
        result = client.transform_chain(
          steps:   [{ transformation: '{"output":"done"}', engine: :static }],
          payload: {}
        )
        expect(result[:success]).to be true
        expect(result[:result][:args]).to eq(output: 'done')
      end
    end

    context 'with multiple steps' do
      it 'pipes output of one step as payload into the next' do
        result = client.transform_chain(
          steps:   [
            { transformation: '{"greeting":"hello"}', engine: :static },
            { transformation: '{"message":"<%= greeting %> world"}', engine: :erb }
          ],
          payload: {}
        )
        expect(result[:success]).to be true
        expect(result[:result][:args]).to eq(message: 'hello world')
      end
    end

    context 'with per-step engine selection' do
      it 'uses each step\'s specified engine independently' do
        result = client.transform_chain(
          steps:   [
            { transformation: '{"name":"Alice"}', engine: :static },
            { transformation: '{"greeting":"hi {{ name }}"}', engine: :liquid }
          ],
          payload: {}
        )
        expect(result[:success]).to be true
        expect(result[:result][:args]).to eq(greeting: 'hi Alice')
      end
    end

    context 'with auto-detected engine' do
      it 'detects the engine when none is specified' do
        result = client.transform_chain(
          steps:   [{ transformation: '{"auto":"detected"}' }],
          payload: {}
        )
        expect(result[:success]).to be true
        expect(result[:result][:args]).to eq(auto: 'detected')
      end
    end

    context 'with schema validation mid-chain' do
      it 'stops and returns failure when schema fails' do
        result = client.transform_chain(
          steps:   [
            { transformation: '{"name":"test"}', engine: :static, schema: { required_keys: %i[name email] } },
            { transformation: '{"final":"done"}', engine: :static }
          ],
          payload: {}
        )
        expect(result[:success]).to be false
        expect(result[:status]).to eq('transformer.validation_failed')
        expect(result[:errors]).to include(a_string_matching(/email/))
      end

      it 'proceeds through all steps when schema passes' do
        result = client.transform_chain(
          steps:   [
            { transformation: '{"name":"Alice"}', engine: :static, schema: { required_keys: [:name] } },
            { transformation: '{"greeting":"hi","name":"<%= name %>"}', engine: :erb }
          ],
          payload: {}
        )
        expect(result[:success]).to be true
        expect(result[:result][:args]).to include(name: 'Alice', greeting: 'hi')
      end
    end

    context 'with engine_options in chain steps' do
      it 'passes per-step engine_options to the engine' do
        result = client.transform_chain(
          steps:   [
            { transformation: '{"name":"Alice"}', engine: :static, engine_options: {} },
            { transformation: '{"greeting":"hi <%= name %>"}', engine: :erb, engine_options: {} }
          ],
          payload: {}
        )
        expect(result[:success]).to be true
      end

      it 'bubbles up failure hashes in chain' do
        failure = { success: false, error: 'timeout' }
        static_engine = Legion::Extensions::Transformer::Engines::Registry.fetch(:static)
        allow(static_engine).to receive(:render).and_return(failure)

        result = client.transform_chain(
          steps:   [
            { transformation: '{}', engine: :static }
          ],
          payload: {}
        )
        expect(result[:success]).to be false
        expect(result[:error]).to eq('timeout')
      end
    end
  end

  describe 'engine_options parameter' do
    context 'with engine_options' do
      it 'passes engine_options through to the engine render call' do
        llm_engine = Legion::Extensions::Transformer::Engines::Registry.fetch(:erb)
        expect(llm_engine).to receive(:render).with(
          '{"val":"<%= num %>"}',
          { num: 42 },
          extra: 'opt'
        ).and_call_original

        client.transform(
          transformation: '{"val":"<%= num %>"}',
          payload:        { num: 42 },
          engine:         :erb,
          engine_options: { extra: 'opt' }
        )
      end

      it 'defaults engine_options to empty hash' do
        result = client.transform(
          transformation: '{"key":"val"}',
          payload:        {}
        )
        expect(result[:success]).to be true
      end

      it 'bubbles up engine failure hashes without schema validation' do
        failure = { success: false, error: 'timeout', message: 'max retries exhausted' }
        static_engine = Legion::Extensions::Transformer::Engines::Registry.fetch(:static)
        allow(static_engine).to receive(:render).and_return(failure)

        result = client.transform(
          transformation: '{}',
          payload:        {},
          engine:         :static,
          schema:         { required_keys: [:impossible] }
        )
        expect(result[:success]).to be false
        expect(result[:error]).to eq('timeout')
      end
    end
  end
end
