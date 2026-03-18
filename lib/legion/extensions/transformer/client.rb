# frozen_string_literal: true

require_relative 'engines/registry'
require_relative 'helpers/schema_validator'

module Legion
  module Extensions
    module Transformer
      class Client
        def transform(transformation:, payload:, engine: nil, schema: nil)
          eng = resolve_engine(engine, transformation)
          rendered = eng.render(transformation, payload)
          rendered = parse_rendered(rendered)

          if schema
            validation = Helpers::SchemaValidator.validate(schema: schema, data: rendered)
            return { success: false, status: 'transformer.validation_failed', errors: validation[:errors] } unless validation[:valid]
          end

          { success: true, result: rendered }
        end

        def transform_chain(steps:, payload:)
          result = payload.dup
          steps.each do |step|
            eng = resolve_engine(step[:engine], step[:transformation])
            rendered = eng.render(step[:transformation], result)
            rendered = parse_rendered(rendered)

            if step[:schema]
              validation = Helpers::SchemaValidator.validate(schema: step[:schema], data: rendered)
              return { success: false, status: 'transformer.validation_failed', errors: validation[:errors] } unless validation[:valid]
            end

            if rendered.is_a?(Hash)
              result = result.merge({ args: rendered }.merge(rendered))
            else
              result[:args] = rendered
            end
          end
          { success: true, result: result }
        end

        private

        def resolve_engine(engine_name, transformation)
          if engine_name
            Engines::Registry.fetch(engine_name)
          else
            Engines::Registry.detect(transformation)
          end
        end

        def parse_rendered(rendered)
          return rendered unless rendered.is_a?(String)

          Legion::JSON.load(rendered)
        rescue StandardError
          rendered
        end
      end
    end
  end
end
