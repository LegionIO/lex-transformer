# frozen_string_literal: true

require_relative 'engines/registry'
require_relative 'helpers/schema_validator'
require_relative 'definitions'

module Legion
  module Extensions
    module Transformer
      class Client
        def transform(payload:, transformation: nil, engine: nil, schema: nil, engine_options: {}, name: nil)
          return transform_by_name(name: name, payload: payload, engine_options: engine_options) if transformation.nil? && name

          eng = resolve_engine(engine, transformation)
          rendered = eng.render(transformation, payload, **engine_options)
          rendered = parse_rendered(rendered)

          return rendered if rendered.is_a?(Hash) && rendered[:success] == false

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
            step_opts = step[:engine_options] || {}
            rendered = eng.render(step[:transformation], result, **step_opts)
            rendered = parse_rendered(rendered)

            return rendered if rendered.is_a?(Hash) && rendered[:success] == false

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

        def transform_by_name(name:, payload:, engine_options: {})
          definition = Definitions.fetch(name)
          return { success: false, error: 'definition_not_found' } unless definition

          if definition[:conditions] && conditioner_available?
            cond_result = evaluate_conditions(definition[:conditions], payload)
            return { success: false, reason: 'conditions_not_met' } unless cond_result
          end

          merged_opts = Definitions.merge_options(definition, **engine_options)

          transform(
            transformation: definition[:transformation],
            payload:        payload,
            engine:         definition[:engine],
            schema:         definition[:schema],
            engine_options: merged_opts
          )
        end

        def conditioner_available?
          defined?(Legion::Extensions::Conditioner::Client)
        end

        def evaluate_conditions(conditions, payload)
          client = Legion::Extensions::Conditioner::Client.new
          result = client.evaluate(conditions: conditions, values: payload)
          result[:passed]
        rescue StandardError
          true
        end

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
