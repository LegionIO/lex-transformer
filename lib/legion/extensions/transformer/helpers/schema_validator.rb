# frozen_string_literal: true

module Legion
  module Extensions
    module Transformer
      module Helpers
        class SchemaValidator
          TYPES = {
            'string' => [String], 'integer' => [Integer], 'number' => [Numeric], 'float' => [Float],
            'boolean' => [TrueClass, FalseClass], 'trueclass' => [TrueClass], 'falseclass' => [FalseClass],
            'object' => [Hash], 'hash' => [Hash], 'array' => [Array], 'null' => [NilClass], 'nilclass' => [NilClass],
            'numeric' => [Numeric]
          }.freeze

          class << self
            def validate(schema:, data:)
              return { valid: true } if schema.nil?
              raise ArgumentError, 'schema must be a Hash' unless schema.is_a?(Hash)

              normalized = schema.transform_keys(&:to_sym)
              required = normalized.fetch(:required_keys) { normalized.fetch(:required, []) }
              types = normalized.fetch(:types, {}).transform_keys(&:to_s)
              normalized.fetch(:properties, {}).each do |key, property|
                type = property[:type] || property['type']
                types[key.to_s] = type if type
              end
              raise ArgumentError, 'required keys must be an Array' unless required.is_a?(Array)

              resolved = types.transform_values { |type| resolve_type(type: type) }
              errors = []
              items = data.is_a?(Array) ? data : [data]
              items.each_with_index do |item, index|
                prefix = data.is_a?(Array) ? "item #{index}: " : ''
                errors.concat(validate_item(data: item, required: required, types: resolved, prefix: prefix))
              end
              errors.empty? ? { valid: true } : { valid: false, errors: errors }
            end

            private

            def validate_item(data:, required:, types:, prefix:)
              return ["#{prefix}expected an object"] unless data.is_a?(Hash)

              values = data.transform_keys(&:to_s)
              errors = []
              required.each { |key| errors << "#{prefix}missing required key: #{key}" unless values.key?(key.to_s) }
              types.each do |key, classes|
                next unless values.key?(key)
                next if classes.any? { |type| values[key].is_a?(type) }

                errors << "#{prefix}#{key} expected #{classes.join(' or ')}, got #{values[key].class}"
              end
              errors
            end

            def resolve_type(type:)
              TYPES.fetch(type.to_s.downcase) { raise ArgumentError, "unsupported schema type: #{type}" }
            end
          end
        end
      end
    end
  end
end
