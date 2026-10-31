# frozen_string_literal: true

require 'digest'
require 'legion/json'
require_relative 'settings'
require_relative 'engines/registry'
require_relative 'helpers/schema_validator'
require_relative 'definitions'

module Legion
  module Extensions
    module Transformer
      class Client
        include Legion::Extensions::Transformer::Helpers::Configuration

        def transform(payload:, transformation: nil, engine: nil, schema: nil, engine_options: {}, name: nil, steps: nil)
          return transform_by_name(name:, payload:, engine:, schema:, engine_options:) if transformation.nil? && name

          if steps
            outcome = transform_chain(steps: steps, payload: payload)
            return outcome unless outcome[:success]

            validation = Legion::Extensions::Transformer::Helpers::SchemaValidator.validate(schema: schema, data: outcome[:result])
            return { success: false, status: task_status(name: :transformer_validation_failed), errors: validation[:errors] } unless validation[:valid]

            return outcome
          end
          raise ArgumentError, 'transformation must be provided' if transformation.nil?
          raise ArgumentError, 'payload must be a Hash' unless payload.is_a?(Hash)

          selected = if engine
                       Legion::Extensions::Transformer::Engines::Registry.fetch(name: engine)
                     else
                       Legion::Extensions::Transformer::Engines::Registry.detect(template: transformation)
                     end
          rendered = selected.render(template: transformation, payload: payload, **engine_options.transform_keys(&:to_sym))
          rendered = Legion::JSON.load(rendered) if rendered.is_a?(String)

          validate_output!(result: rendered)
          validation = Legion::Extensions::Transformer::Helpers::SchemaValidator.validate(schema: schema, data: rendered)
          return { success: false, status: task_status(name: :transformer_validation_failed), errors: validation[:errors] } unless validation[:valid]

          revision = Digest::SHA256.hexdigest(Legion::JSON.dump({ transformation: transformation, engine: selected.name,
                                                                schema: schema, engine_options: engine_options }))
          { success: true, result: rendered, definition_version: revision }
        rescue StandardError, LoadError => e
          handle_exception(e, level: :error, handled: true)
          { success: false, status: task_status(name: :transformer_failed), error: e.class.name, message: e.message }
        end

        def transform_chain(steps:, payload:)
          raise ArgumentError, 'steps must be a nonempty Array' unless steps.is_a?(Array) && !steps.empty?
          raise ArgumentError, 'payload must be a Hash' unless payload.is_a?(Hash)

          context = payload.dup
          revisions = []
          outcome = nil
          steps.each do |step|
            raise ArgumentError, 'each transform step must be a Hash' unless step.is_a?(Hash)

            outcome = transform(payload: context, **step.transform_keys(&:to_sym))
            return outcome unless outcome[:success]

            rendered = outcome[:result]
            revisions << outcome[:definition_version]
            context = context.merge(rendered) if rendered.is_a?(Hash)
            context = context.merge(args: rendered)
          end
          outcome.merge(definition_version: Digest::SHA256.hexdigest(revisions.join(':')))
        rescue StandardError => e
          handle_exception(e, level: :error, handled: true)
          { success: false, status: task_status(name: :transformer_failed), error: e.class.name, message: e.message }
        end

        private

        def transform_by_name(name:, payload:, engine:, schema:, engine_options:)
          definition = Legion::Extensions::Transformer::Definitions.fetch(name: name)
          raise ArgumentError, "transformer definition not found: #{name}" unless definition

          if definition.key?(:conditions)
            require 'legion/extensions/conditioner/client'
            condition = Legion::Extensions::Conditioner::Client.new.evaluate(conditions: definition[:conditions], values: payload)
            unless condition[:valid] == true
              return { success: false, status: task_status(name: :skipped), reason: 'conditions_not_met', explanation: condition[:explanation] }
            end
          end
          engine_options = (definition[:engine_options] || {}).transform_keys(&:to_sym).merge(engine_options)
          outcome = transform(payload: payload, transformation: definition[:transformation], engine: engine || definition[:engine],
                              schema: schema || definition[:schema], engine_options: engine_options, steps: definition[:steps])
          return outcome unless outcome[:success]

          revision = Digest::SHA256.hexdigest(Legion::JSON.dump({ definition: definition, effective_revision: outcome[:definition_version] }))
          outcome.merge(definition_version: revision)
        end

        def validate_output!(result:)
          raise ArgumentError, 'transform output must be a Hash or an Array of Hashes' unless result.is_a?(Hash) || (result.is_a?(Array) && result.all?(Hash))
          return unless result.is_a?(Array)

          limit = transformer_execution_settings.fetch(:max_fanout)
          raise ArgumentError, "transform output exceeds max_fanout #{limit}" if result.length > limit
        end
      end
    end
  end
end
