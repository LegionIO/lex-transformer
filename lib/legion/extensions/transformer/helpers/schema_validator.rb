# frozen_string_literal: true

module Legion
  module Extensions
    module Transformer
      module Helpers
        class SchemaValidator
          class << self
            def validate(schema:, data:)
              return { valid: true } if schema.nil? || schema.empty?

              errors = []
              data ||= {}

              check_required_keys(schema[:required_keys], data, errors)
              check_types(schema[:types], data, errors)

              errors.empty? ? { valid: true } : { valid: false, errors: errors }
            end

            private

            def check_required_keys(required_keys, data, errors)
              return if required_keys.nil? || required_keys.empty?

              required_keys.each do |key|
                errors << "missing required key: #{key}" unless data.key?(key)
              end
            end

            def check_types(types, data, errors)
              return if types.nil? || types.empty?

              types.each do |key, expected_type|
                next unless data.key?(key)

                actual = data[key]
                next if actual.is_a?(expected_type)

                errors << "#{key} expected #{expected_type}, got #{actual.class}"
              end
            end
          end
        end
      end
    end
  end
end
