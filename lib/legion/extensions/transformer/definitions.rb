# frozen_string_literal: true

module Legion
  module Extensions
    module Transformer
      class Definitions
        class << self
          def fetch(name)
            defns = load_definitions
            return nil unless defns&.key?(name)

            symbolize_definition(defns[name])
          end

          def names
            defns = load_definitions
            return [] unless defns

            defns.keys
          end

          def merge_options(definition, **overrides)
            base = definition[:engine_options] || {}
            base.merge(overrides)
          end

          private

          def load_definitions
            return nil unless defined?(Legion::Settings)

            Legion::Settings.dig('lex-transformer', 'definitions')
          rescue StandardError
            nil
          end

          def symbolize_definition(raw)
            defn = {}
            defn[:transformation] = raw['transformation'] || raw[:transformation]
            defn[:engine] = (raw['engine'] || raw[:engine])&.to_sym
            defn[:engine_options] = symbolize_hash(raw['engine_options'] || raw[:engine_options] || {})
            defn[:schema] = raw['schema'] || raw[:schema]
            defn[:conditions] = raw['conditions'] || raw[:conditions]
            defn
          end

          def symbolize_hash(hash)
            return {} unless hash.is_a?(Hash)

            hash.transform_keys(&:to_sym)
          end
        end
      end
    end
  end
end
