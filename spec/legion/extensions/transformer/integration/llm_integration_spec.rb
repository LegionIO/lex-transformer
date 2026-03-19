# frozen_string_literal: true

require 'spec_helper'
require 'legion/extensions/transformer/client'
require 'legion/extensions/transformer/engines/llm'
require 'legion/extensions/transformer/definitions'

LlmChatResponse = Struct.new(:content) unless defined?(LlmChatResponse)

unless defined?(Legion::LLM)
  module Legion
    module LLM
    end
  end
end

unless Legion::LLM.respond_to?(:start_stub)
  module Legion
    module LLM
      class << self
        def started?
          @started
        end

        def start_stub
          @started = true
        end

        def stop_stub
          @started = false
        end

        def chat(**)
          LlmChatResponse.new('{"result":"default"}')
        end
      end
    end
  end
end

RSpec.describe 'LLM Engine Integration' do
  subject(:client) { Legion::Extensions::Transformer::Client.new }

  before do
    Legion::LLM.start_stub
    stub_const('Legion::Extensions::Transformer::Engines::Llm::RETRY_SLEEP', 0)
  end

  after { Legion::LLM.stop_stub }

  describe 'Client.transform with engine: :llm' do
    it 'executes an LLM transform end-to-end' do
      allow(Legion::LLM).to receive(:chat).and_return(
        LlmChatResponse.new('{"summary":"all good","status":"success"}')
      )

      result = client.transform(
        transformation: 'Summarize this data',
        payload:        { logs: %w[line1 line2] },
        engine:         :llm
      )

      expect(result[:success]).to be true
      expect(result[:result]).to eq(summary: 'all good', status: 'success')
    end

    it 'passes engine_options to LLM' do
      expect(Legion::LLM).to receive(:chat).with(
        hash_including(model: 'ollama/llama3', temperature: 0.1)
      ).and_return(LlmChatResponse.new('{"ok":true}'))

      client.transform(
        transformation: 'Transform',
        payload:        { data: 1 },
        engine:         :llm,
        engine_options: { model: 'ollama/llama3', temperature: 0.1 }
      )
    end

    it 'returns failure hash when LLM times out after retries' do
      allow(Legion::LLM).to receive(:chat).and_raise(Timeout::Error)

      result = client.transform(
        transformation: 'Transform',
        payload:        { data: 1 },
        engine:         :llm,
        engine_options: { max_retries: 0 }
      )

      expect(result[:success]).to be false
      expect(result[:error]).to eq('timeout')
    end

    it 'validates LLM output against schema' do
      allow(Legion::LLM).to receive(:chat).and_return(
        LlmChatResponse.new('{"name":"Alice"}')
      )

      result = client.transform(
        transformation: 'Extract user',
        payload:        { raw: 'data' },
        engine:         :llm,
        schema:         { required_keys: %i[name email] }
      )

      expect(result[:success]).to be false
      expect(result[:errors]).to include(a_string_matching(/email/))
    end
  end

  describe 'transform_chain with mixed engines' do
    it 'pipes ERB output into LLM step' do
      allow(Legion::LLM).to receive(:chat).and_return(
        LlmChatResponse.new('{"greeting":"hello from LLM"}')
      )

      result = client.transform_chain(
        steps:   [
          { transformation: '{"name":"<%= user %>"}', engine: :erb },
          { transformation: 'Generate a greeting for the person', engine: :llm }
        ],
        payload: { user: 'Alice' }
      )

      expect(result[:success]).to be true
      expect(result[:result][:args][:greeting]).to eq('hello from LLM')
    end

    it 'does not leak engine_options between chain steps' do
      call_opts = []
      allow(Legion::LLM).to receive(:chat) do |**kwargs|
        call_opts << kwargs.dup
        LlmChatResponse.new('{"step":"done"}')
      end

      client.transform_chain(
        steps:   [
          { transformation: 'Step 1', engine: :llm, engine_options: { model: 'model_a' } },
          { transformation: 'Step 2', engine: :llm, engine_options: { model: 'model_b' } }
        ],
        payload: { data: 1 }
      )

      expect(call_opts[0][:model]).to eq('model_a')
      expect(call_opts[1][:model]).to eq('model_b')
    end

    it 'stops chain on LLM failure' do
      allow(Legion::LLM).to receive(:chat).and_raise(Timeout::Error)

      result = client.transform_chain(
        steps:   [
          { transformation: 'Fail here', engine: :llm, engine_options: { max_retries: 0 } },
          { transformation: '{"should":"not run"}', engine: :static }
        ],
        payload: { data: 1 }
      )

      expect(result[:success]).to be false
      expect(result[:error]).to eq('timeout')
    end
  end

  describe 'Client.transform with name:' do
    before do
      allow(Legion::Extensions::Transformer::Definitions).to receive(:fetch)
        .with('test_llm_def')
        .and_return({
                      transformation: 'Summarize the input',
                      engine:         :llm,
                      engine_options: { model: 'ollama/llama3', temperature: 0.2 },
                      schema:         nil,
                      conditions:     nil
                    })

      allow(Legion::Extensions::Transformer::Definitions).to receive(:merge_options) do |defn, **overrides|
        (defn[:engine_options] || {}).merge(overrides)
      end
    end

    it 'executes named LLM definition' do
      expect(Legion::LLM).to receive(:chat).with(
        hash_including(model: 'ollama/llama3', temperature: 0.2)
      ).and_return(LlmChatResponse.new('{"summary":"done"}'))

      result = client.transform(
        name:    'test_llm_def',
        payload: { logs: ['entry'] }
      )

      expect(result[:success]).to be true
      expect(result[:result]).to eq(summary: 'done')
    end

    it 'allows per-call override of definition engine_options' do
      expect(Legion::LLM).to receive(:chat).with(
        hash_including(model: 'claude-sonnet-4-20250514')
      ).and_return(LlmChatResponse.new('{"summary":"overridden"}'))

      result = client.transform(
        name:           'test_llm_def',
        payload:        { logs: ['entry'] },
        engine_options: { model: 'claude-sonnet-4-20250514' }
      )

      expect(result[:success]).to be true
    end
  end
end
