# frozen_string_literal: true

require 'securerandom'
require 'legion/data'
require 'legion/transport'
require 'legion/transport/messages/dynamic'
require 'legion/transport/messages/task'
require_relative '../client'

module Legion
  module Extensions
    module Transformer
      module Runners
        module Transform
          extend self

          include Legion::Transport::Task::Protocol::Helper
          include Legion::Logging::Helper

          def transform(transformation: nil, engine: nil, schema: nil, engine_options: {}, name: nil, steps: nil, **payload)
            request = { transformation: transformation, engine: engine, schema: schema, engine_options: engine_options, name: name, steps: steps }
            envelope = payload.merge(engine: engine, schema: schema, engine_options: engine_options)
            return transformer_persisted(envelope: envelope, request: request) if Legion::Data.connected? && payload[:task_id]

            context = payload[:args].is_a?(Hash) ? payload[:args].merge(payload) : payload
            outcome = Legion::Extensions::Transformer::Client.new.transform(payload: context, **request)
            return outcome unless outcome[:success]

            transformer_check_dispatch!(envelope: envelope)

            transformer_dispatch(envelope: envelope.merge(definition_version: outcome[:definition_version]), result: outcome[:result], persisted: false)
            outcome.merge(task_id: payload[:task_id], durable: false)
          rescue StandardError => e
            handle_exception(e, level: :error, handled: false)
            raise
          end

          private

          def transformer_persisted(envelope:, request:)
            row = Legion::Data::Model::Task[envelope.fetch(:task_id)]
            raise ArgumentError, "task #{envelope[:task_id]} does not exist" unless row

            stopped = transformer_stopped(task: row)
            return stopped if stopped

            context = envelope[:args].is_a?(Hash) ? envelope[:args].merge(envelope) : envelope
            outcome = Legion::Extensions::Transformer::Client.new.transform(payload: context, **request)
            stopped = transformer_stopped(task: row.refresh)
            return stopped if stopped

            unless outcome[:success]
              row.update(status: outcome.fetch(:status), results: Legion::JSON.dump(outcome))
              return outcome.merge(task_id: envelope[:task_id], durable: false)
            end

            target = envelope.merge(definition_version: outcome.fetch(:definition_version))
            transformer_check_dispatch!(envelope: target)
            transformer_dispatch(envelope: target, result: outcome[:result], persisted: true)
            outcome.merge(task_id: envelope[:task_id], durable: false)
          end

          def transformer_stopped(task:)
            status = task[:status]
            if task[:cancelled_at] && !task_terminal_status?(status: status)
              status = task_status(name: :cancelled)
              task.update(status: status)
            end
            return unless task_terminal_status?(status: status) || status == task_status(name: :running) || status == 'running'

            successful_statuses = [task_status(name: :completed), task_status(name: :multiplied), 'completed', 'complete', 'multiplied']
            { success: successful_statuses.include?(status),
              status: status, task_id: task[:id], duplicate: true, durable: false }
          end

          def transformer_check_dispatch!(envelope:)
            target_id = Legion::Data.connected? && envelope[:function_id]
            explicit_target = envelope[:function].is_a?(String) && !envelope[:function].empty? &&
                              envelope[:runner_routing_key].is_a?(String) && !envelope[:runner_routing_key].empty?
            raise ArgumentError, 'target function_id or explicit function and runner_routing_key is required' unless target_id || explicit_target

            max_depth = settings[:execution].fetch(:max_depth)
            raise ArgumentError, 'transformer execution.max_depth must be a positive Integer' unless max_depth.is_a?(Integer) && max_depth.positive?

            raise ArgumentError, "task depth exceeds #{max_depth}" if envelope.fetch(:depth, 0).to_i > max_depth
          end

          def transformer_dispatch(envelope:, result:, persisted:)
            metadata = envelope.slice(*Legion::Transport::Task::Protocol::METADATA_FIELDS)
            if result.is_a?(Array)
              transformer_fanout(metadata: metadata, result: result, persisted: persisted)
            else
              options = metadata.merge(args: result)
              if persisted
                Legion::Data::Model::Task[metadata.fetch(:task_id)].update(
                  status: task_status(name: :queued), function_args: Legion::JSON.dump(result), payload: Legion::JSON.dump(options)
                )
              end
              transformer_publish(options: options)
            end
          end

          def transformer_fanout(metadata:, result:, persisted:)
            depth = metadata.fetch(:depth, 0).to_i + 1
            execution = settings[:execution]
            max_depth = execution.fetch(:max_depth)
            raise ArgumentError, 'transformer execution.max_depth must be a positive Integer' unless max_depth.is_a?(Integer) && max_depth.positive?

            raise ArgumentError, "fanout depth exceeds #{max_depth}" if depth > max_depth

            max_fanout = execution.fetch(:max_fanout)
            raise ArgumentError, 'transformer execution.max_fanout must be a positive Integer' unless max_fanout.is_a?(Integer) && max_fanout.positive?

            raise ArgumentError, "transform output exceeds max_fanout #{max_fanout}" if result.length > max_fanout

            result.each do |args|
              child = metadata.except(:task_id, :message_id).merge(parent_id: metadata[:task_id], master_id: metadata[:master_id] || metadata[:task_id],
                                                                   depth: depth, args: args, message_id: SecureRandom.uuid)
              if persisted
                row = Legion::Data::Model::Task.create(
                  child.slice(*Legion::Data::Model::Task.columns).merge(
                    status: task_status(name: :queued), function_args: Legion::JSON.dump(args), payload: Legion::JSON.dump(child)
                  )
                )
                child[:task_id] = row.pk
              end
              transformer_publish(options: child)
            end
            return unless persisted

            Legion::Data::Model::Task[metadata.fetch(:task_id)].update(status:  task_status(name: :multiplied),
                                                                       results: Legion::JSON.dump(result))
          end

          def transformer_publish(options:)
            return Legion::Transport::Messages::Dynamic.new(**options).publish! if Legion::Data.connected? && options[:function_id]

            Legion::Transport::Messages::Task.new(**options, routing_key: options.fetch(:runner_routing_key)).publish!
          end
        end
      end
    end
  end
end
