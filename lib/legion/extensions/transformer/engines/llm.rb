# frozen_string_literal: true

require 'timeout'
require_relative 'base'

module Legion
  module Extensions
    module Transformer
      module Engines
        class Llm < Base
          AUTH_ERRORS = /auth|credentials|forbidden|api.key|unauthorized/i
          RETRY_SLEEP = 1

          def name
            :llm
          end

          def render(prompt, payload, **opts)
            raise 'Legion::LLM is not available or not started' unless llm_available?

            @last_raw = nil
            resolved = resolve_options(opts)
            max_retries = resolved.delete(:max_retries)
            attempts = 0

            loop do
              result = attempt_render(prompt, payload, resolved, attempts)
              return result unless result == :retry

              attempts += 1
              return build_failure if attempts > max_retries

              sleep(RETRY_SLEEP)
            end
          end

          private

          def llm_available?
            defined?(Legion::LLM) && Legion::LLM.respond_to?(:started?) && Legion::LLM.started?
          end

          def resolve_options(opts)
            defaults = settings_defaults
            resolved = defaults.merge(opts)
            resolved[:max_retries] = (resolved[:max_retries] || 1).to_i
            resolved
          end

          def settings_defaults
            return {} unless defined?(Legion::Settings)

            settings = begin
              Legion::Settings.dig('lex-transformer', 'llm')
            rescue StandardError
              nil
            end
            return {} unless settings.is_a?(Hash)

            settings.transform_keys(&:to_sym)
          end

          def attempt_render(prompt, payload, opts, attempt)
            chat = call_llm(prompt, payload, opts, attempt)
            content = extract_response(chat)
            validate_json(content)
            content
          rescue Timeout::Error, IOError, Errno::ECONNREFUSED, Errno::ECONNRESET
            :retry
          rescue ::JSON::ParserError
            @last_raw = content
            :retry
          rescue RuntimeError => e
            raise if auth_error?(e)

            { success: false, error: e.class.to_s, message: e.message }
          rescue StandardError => e
            { success: false, error: e.class.to_s, message: e.message }
          end

          def call_llm(prompt, payload, opts, attempt)
            context = Legion::JSON.dump(payload)

            return call_structured(prompt, context, opts) if opts[:structured] && opts[:schema] && structured_available?

            full_prompt = build_prompt(prompt, context, attempt)
            full_prompt = inject_schema_into_prompt(full_prompt, opts[:schema]) if opts[:structured] && opts[:schema]

            llm_opts = build_llm_opts(opts)
            Legion::LLM.chat(message: full_prompt, **llm_opts)
          end

          def structured_available?
            Legion::LLM.respond_to?(:structured)
          end

          def call_structured(prompt, context, opts)
            llm_opts = build_llm_opts(opts)
            Legion::LLM.structured(
              message: "#{prompt}\n\nPayload:\n```json\n#{context}\n```",
              schema:  opts[:schema],
              **llm_opts
            )
          end

          def inject_schema_into_prompt(prompt, schema)
            schema_json = Legion::JSON.dump(schema)
            "#{prompt}\n\nYour response MUST conform to this JSON schema:\n```json\n#{schema_json}\n```"
          end

          def build_prompt(prompt, context, attempt)
            base = "#{prompt}\n\nPayload:\n```json\n#{context}\n```\n\nRespond with valid JSON only. No explanation, no markdown fences."
            return base unless attempt.positive?

            "#{base}\n\nIMPORTANT: Your previous response was not valid JSON. Return ONLY a valid JSON object or array, nothing else."
          end

          def extract_response(chat)
            content = chat.respond_to?(:content) ? chat.content : chat.to_s
            content = content.strip
            content = content.sub(/\A```(?:json)?\n?/, '').sub(/\n?```\z/, '') if content.start_with?('```')
            content
          end

          def validate_json(content)
            ::JSON.parse(content)
          end

          def auth_error?(error)
            AUTH_ERRORS.match?(error.message)
          end

          def build_llm_opts(opts)
            llm_opts = {}
            llm_opts[:model] = opts[:model] if opts[:model]
            llm_opts[:provider] = opts[:provider] if opts[:provider]
            llm_opts[:temperature] = opts[:temperature] if opts[:temperature]
            llm_opts[:system_prompt] = opts[:system_prompt] if opts[:system_prompt]
            llm_opts
          end

          def build_failure
            if @last_raw
              { success: false, error: 'invalid_json', message: 'max retries exhausted', raw: @last_raw }
            else
              { success: false, error: 'timeout', message: 'max retries exhausted' }
            end
          end
        end
      end
    end
  end
end
