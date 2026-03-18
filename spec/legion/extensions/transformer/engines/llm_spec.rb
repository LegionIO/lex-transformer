# frozen_string_literal: true

require 'spec_helper'
require 'legion/extensions/transformer/engines/llm'

LlmChatResponse = Struct.new(:content)

# Stub Legion::LLM for testing
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
        LlmChatResponse.new('{"result":"transformed"}')
      end
    end
  end
end

RSpec.describe Legion::Extensions::Transformer::Engines::Llm do
  subject(:engine) { described_class.new }

  describe '#name' do
    it 'returns :llm' do
      expect(engine.name).to eq(:llm)
    end
  end

  describe '#render' do
    context 'when Legion::LLM is started' do
      before { Legion::LLM.start_stub }
      after { Legion::LLM.stop_stub }

      it 'sends prompt with payload context to LLM' do
        result = engine.render('Summarize this data', { name: 'Alice', role: 'admin' })
        expect(result).to be_a(String)
      end

      it 'returns the LLM response content' do
        result = engine.render('Transform this', { key: 'value' })
        expect(result).to eq('{"result":"transformed"}')
      end

      it 'includes the payload as JSON in the prompt' do
        expect(Legion::LLM).to receive(:chat).with(
          hash_including(message: a_string_including('"name":"Alice"'))
        ).and_return(LlmChatResponse.new('{"out":"ok"}'))

        engine.render('Do something', { name: 'Alice' })
      end

      it 'strips markdown code fences from response' do
        allow(Legion::LLM).to receive(:chat).and_return(
          LlmChatResponse.new("```json\n{\"key\":\"value\"}\n```")
        )
        result = engine.render('Transform', { data: 1 })
        expect(result).to eq('{"key":"value"}')
      end

      it 'handles response without content method' do
        allow(Legion::LLM).to receive(:chat).and_return('plain string response')
        result = engine.render('Transform', { data: 1 })
        expect(result).to eq('plain string response')
      end
    end

    context 'when Legion::LLM is not started' do
      before { Legion::LLM.stop_stub }

      it 'raises RuntimeError' do
        expect { engine.render('Transform', { key: 'value' }) }.to raise_error(RuntimeError, /not available/)
      end
    end
  end
end
