# frozen_string_literal: true

require_relative '../../transformer'
require_relative 'erb'
require_relative 'static'
require_relative 'liquid'
require_relative 'jsonpath'
require_relative 'llm'

module Legion
  module Extensions
    module Transformer
      module Engines
        class Registry
          class << self
            def register(engine_class:)
              @engines ||= {}
              instance = engine_class.new
              @engines[instance.name.to_s] = instance
            end

            def fetch(name:)
              key = name.to_s
              allowed = Legion::Settings[:extensions][:transformer][:allowed_engines]
              unless allowed.is_a?(Hash) && allowed.values.all? { |value| [true, false].include?(value) }
                raise ArgumentError, 'allowed_engines must be a Hash of Boolean grants'
              end
              raise ArgumentError, 'allowed_engines contains duplicate logical engine names' if allowed.keys.map(&:to_s).uniq.length != allowed.length

              enabled = allowed.fetch(key.to_sym) { allowed[key] }
              raise ArgumentError, "engine is not allowed: #{key}" unless enabled == true

              if Legion::Settings[:extensions][:transformer][:trusted_engines].map(&:to_s).include?(key) &&
                 !Legion::Settings[:extensions][:transformer][:allow_trusted_engines]
                raise ArgumentError, "engine #{key} executes trusted code; enable allow_trusted_engines only for administrator-owned templates"
              end

              @engines.fetch(key) { raise ArgumentError, "Unknown engine: #{name}" }
            end

            def detect(template:)
              templated = template.is_a?(String) && Legion::Settings[:extensions][:transformer][:template_markers].any? { |marker| template.include?(marker) }
              fetch(name: Legion::Settings[:extensions][:transformer][templated ? :template_engine : :default_engine])
            end
          end

          register(engine_class: Legion::Extensions::Transformer::Engines::Erb)
          register(engine_class: Legion::Extensions::Transformer::Engines::Static)
          register(engine_class: Legion::Extensions::Transformer::Engines::Liquid)
          register(engine_class: Legion::Extensions::Transformer::Engines::Jsonpath)
          register(engine_class: Legion::Extensions::Transformer::Engines::Llm)
        end
      end
    end
  end
end
