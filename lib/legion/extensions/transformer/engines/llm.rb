# frozen_string_literal: true

require_relative 'base'

module Legion
  module Extensions
    module Transformer
      module Engines
        class Llm < Base
          def name
            :llm
          end

          def render(prompt, payload, **opts)
            raise 'Legion::LLM is not available or not started' unless defined?(Legion::LLM) && Legion::LLM.respond_to?(:started?) && Legion::LLM.started?

            context = Legion::JSON.dump(payload)
            full_prompt = "#{prompt}\n\nPayload:\n```json\n#{context}\n```\n\nRespond with valid JSON only. No explanation, no markdown fences."

            chat = Legion::LLM.chat(message: full_prompt)
            extract_response(chat)
          end

          private

          def extract_response(chat)
            content = chat.respond_to?(:content) ? chat.content : chat.to_s
            content = content.strip
            content = content.sub(/\A```(?:json)?\n?/, '').sub(/\n?```\z/, '') if content.start_with?('```')
            content
          end
        end
      end
    end
  end
end
