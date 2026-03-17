# frozen_string_literal: true

require_relative '../engines/registry'

module Legion
  module Extensions
    module Transformer
      module Runners
        module Transform
          def transform(transformation:, engine: nil, **payload)
            payload[:args] = render_transformation(transformation, payload, engine: engine)
            dispatch_transformed(payload)
            generate_task_log(task_id: payload[:task_id], function: 'transform', values: payload) if payload[:debug] && payload.key?(:task_id)
            { success: true, **payload }
          end

          def render_transformation(transformation, payload, engine: nil)
            eng = if engine
                    Engines::Registry.fetch(engine)
                  else
                    Engines::Registry.detect(transformation)
                  end

            rendered = eng.render(transformation, payload)
            rendered.is_a?(String) ? from_json(rendered) : rendered
          end

          def dispatch_transformed(payload)
            case payload[:args]
            when Hash
              task_update(payload[:task_id], 'transformer.succeeded', function_args: payload[:args]) unless payload[:task_id].nil?
              send_task(**payload)
              task_update(payload[:task_id], 'task.queued', use_database: false) unless payload[:task_id].nil?
            when Array
              dispatch_multiplied(payload)
            end
          end

          def dispatch_multiplied(payload)
            payload[:args].each do |thing|
              new_payload = payload.dup
              task = Legion::Runner::Status.generate_task_id(function_args: thing, status: 'task.queued', args: thing, **new_payload)
              new_payload[:task_id] = task[:task_id]
              new_payload[:args] = thing
              send_task(**new_payload)
            end
            task_update(payload[:task_id], 'task.multiplied', function_args: payload[:args]) unless payload[:task_id].nil?
          end

          def send_task(**opts)
            payload = {}
            %i[task_id relationship_id trigger_function_id runner_class function_id function chain_id debug args].each do |thing|
              payload[thing] = opts[thing] if opts.key? thing
            end

            Legion::Extensions::Transformer::Transport::Messages::Message.new(**payload).publish
          end

          include Legion::Extensions::Helpers::Lex
          extend Legion::Extensions::Helpers::Task
        end
      end
    end
  end
end
