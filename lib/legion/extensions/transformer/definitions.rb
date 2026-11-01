# frozen_string_literal: true

require_relative 'settings'

module Legion
  module Extensions
    module Transformer
      class Definitions
        class << self
          def fetch(name:)
            definitions = Legion::Settings[:extensions][:transformer][:definitions]
            raise ArgumentError, 'transformer definitions must be a Hash' unless definitions.is_a?(Hash)

            raw = definitions[name.to_sym] || definitions[name.to_s]
            return if raw.nil?
            raise ArgumentError, "transformer definition #{name} must be a Hash" unless raw.is_a?(Hash)

            raw.transform_keys(&:to_sym)
          end

          def names
            Legion::Settings[:extensions][:transformer][:definitions].keys
          end
        end
      end
    end
  end
end
