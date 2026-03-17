# frozen_string_literal: true

require_relative 'erb'
require_relative 'static'

module Legion
  module Extensions
    module Transformer
      module Engines
        class Registry
          ENGINES = {}.freeze

          class << self
            def register(engine_class)
              @engines ||= {}
              instance = engine_class.new
              @engines[instance.name] = instance
              @engines[instance.name.to_s] = instance
            end

            def fetch(name)
              @engines ||= {}
              @engines[name.to_sym] || @engines[name.to_s] || raise(ArgumentError, "Unknown engine: #{name}")
            end

            def detect(template)
              if template.is_a?(String) && (template.include?('<%') || template.include?('%>'))
                fetch(:erb)
              else
                fetch(:static)
              end
            end

            def reset!
              @engines = {}
            end
          end

          register(Erb)
          register(Static)
        end
      end
    end
  end
end
