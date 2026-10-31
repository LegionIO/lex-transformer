# frozen_string_literal: true

require_relative 'settings'

module Legion
  module Extensions
    module Transformer
      class Definitions
        extend Legion::Extensions::Transformer::Helpers::Configuration

        class << self
          def fetch(name:)
            definitions = settings.fetch(:definitions)
            raise ArgumentError, 'transformer definitions must be a Hash' unless definitions.is_a?(Hash)

            raw = definitions[name.to_sym] || definitions[name.to_s]
            return if raw.nil?
            raise ArgumentError, "transformer definition #{name} must be a Hash" unless raw.is_a?(Hash)

            raw.transform_keys(&:to_sym)
          end

          def names
            settings.fetch(:definitions).keys
          end
        end
      end
    end
  end
end
