# frozen_string_literal: true

require 'timeout'
require 'legion/json'
require_relative '../settings'
require_relative 'base'

module Legion
  module Extensions
    module Transformer
      module Engines
        class Llm < Base
          include Legion::Logging::Helper

          def name
            :llm
          end

          def render(template:, payload:, **opts)
            raise 'Legion::LLM is not available or not started' unless defined?(Legion::LLM) && Legion::LLM.respond_to?(:started?) && Legion::LLM.started?

            options = Legion::Settings[:extensions][:transformer][:llm].merge(opts)
            retries = Integer(options.fetch(:max_retries))
            raise ArgumentError, 'max_retries must not be negative' if retries.negative?

            attempt = 0
            loop do
              content = extract_response(chat: call_llm(prompt: template, payload: payload, opts: options, attempt: attempt))
              Legion::JSON.load(content)
              return content
            rescue Timeout::Error, IOError, Errno::ECONNREFUSED, Errno::ECONNRESET, Legion::JSON::ParseError => e
              handle_exception(e, level: :warn, handled: attempt < retries)
              raise if attempt >= retries

              attempt += 1
              sleep(options.fetch(:retry_delay_seconds))
            rescue StandardError => e
              handle_exception(e, level: :error, handled: false)
              raise
            end
          end

          private

          def call_llm(prompt:, payload:, opts:, attempt:)
            context = Legion::JSON.dump(payload)
            llm_opts = opts.slice(:model, :provider, :temperature, :system_prompt, :caller)
            if opts[:structured] && opts[:schema] && Legion::LLM.respond_to?(:structured)
              return Legion::LLM.structured(message: "#{prompt}\n\nPayload:\n```json\n#{context}\n```", schema: opts[:schema], **llm_opts)
            end

            message = "#{prompt}\n\nPayload:\n```json\n#{context}\n```\n\nRespond with valid JSON only. No explanation, no markdown fences."
            message += '\nReturn ONLY a valid JSON object or array; the previous response was invalid.' if attempt.positive?
            message += "\n\nJSON schema:\n#{Legion::JSON.dump(opts[:schema])}" if opts[:structured] && opts[:schema]
            Legion::LLM.chat(message: message, **llm_opts)
          end

          def extract_response(chat:)
            content = (chat.respond_to?(:content) ? chat.content : chat.to_s).strip
            return content unless content.start_with?('```')

            content.sub(/\A```(?:json)?\n?/, '').sub(/\n?```\z/, '')
          end
        end
      end
    end
  end
end
