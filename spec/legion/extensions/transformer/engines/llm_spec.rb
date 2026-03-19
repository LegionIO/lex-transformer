# frozen_string_literal: true

require 'spec_helper'
require 'timeout'
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

      it 'handles response without content method (non-JSON returns failure)' do
        stub_const('Legion::Extensions::Transformer::Engines::Llm::RETRY_SLEEP', 0)
        allow(Legion::LLM).to receive(:chat).and_return('plain string response')
        result = engine.render('Transform', { data: 1 }, max_retries: 0)
        expect(result).to eq({ success: false, error: 'invalid_json', message: 'max retries exhausted', raw: 'plain string response' })
      end

      context 'retry behavior' do
        before { stub_const('Legion::Extensions::Transformer::Engines::Llm::RETRY_SLEEP', 0) }

        it 'retries on timeout and succeeds on second attempt' do
          call_count = 0
          allow(Legion::LLM).to receive(:chat) do
            call_count += 1
            raise Timeout::Error if call_count == 1

            LlmChatResponse.new('{"result":"ok"}')
          end

          result = engine.render('Transform', { data: 1 }, max_retries: 1)
          expect(call_count).to eq(2)
          expect(result).to eq('{"result":"ok"}')
        end

        it 'returns failure hash after exhausting timeout retries' do
          allow(Legion::LLM).to receive(:chat).and_raise(Timeout::Error)

          result = engine.render('Transform', { data: 1 }, max_retries: 1)
          expect(result).to eq({ success: false, error: 'timeout', message: 'max retries exhausted' })
        end

        it 'retries with correction prompt on invalid JSON and succeeds on second attempt' do
          call_count = 0
          allow(Legion::LLM).to receive(:chat) do
            call_count += 1
            if call_count == 1
              LlmChatResponse.new('not valid json at all')
            else
              LlmChatResponse.new('{"result":"fixed"}')
            end
          end

          result = engine.render('Transform', { data: 1 }, max_retries: 1)
          expect(call_count).to eq(2)
          expect(result).to eq('{"result":"fixed"}')
        end

        it 'returns failure with raw after exhausting invalid JSON retries' do
          allow(Legion::LLM).to receive(:chat).and_return(LlmChatResponse.new('not valid json'))

          result = engine.render('Transform', { data: 1 }, max_retries: 1)
          expect(result).to eq({ success: false, error: 'invalid_json', message: 'max retries exhausted', raw: 'not valid json' })
        end

        it 'raises immediately on auth errors without retrying' do
          call_count = 0
          allow(Legion::LLM).to receive(:chat) do
            call_count += 1
            raise RuntimeError, 'authentication failed'
          end

          expect { engine.render('Transform', { data: 1 }, max_retries: 2) }.to raise_error(RuntimeError, 'authentication failed')
          expect(call_count).to eq(1)
        end

        it 'returns failure hash on generic provider errors without retrying' do
          allow(Legion::LLM).to receive(:chat).and_raise(StandardError, 'provider unavailable')

          result = engine.render('Transform', { data: 1 }, max_retries: 1)
          expect(result).to eq({ success: false, error: 'StandardError', message: 'provider unavailable' })
        end

        it 'defaults to max_retries: 1 (2 total attempts) when not specified' do
          call_count = 0
          allow(Legion::LLM).to receive(:chat) do
            call_count += 1
            raise Timeout::Error
          end

          result = engine.render('Transform', { data: 1 })
          expect(call_count).to eq(2)
          expect(result[:error]).to eq('timeout')
        end
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
