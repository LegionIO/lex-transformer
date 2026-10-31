# frozen_string_literal: true

require 'time'
require 'legion/data'
require 'legion/data/task_execution'
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

          include Legion::Extensions::Transformer::Helpers::Configuration

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

            values = row.values
            stopped = transformer_stopped(task: values)
            return stopped if stopped

            recorded = values[:transformation_result] && Legion::JSON.load(values[:transformation_result])
            return recorded.merge(task_id: values[:id], status: values[:status], durable: true, duplicate: true) if recorded

            context = envelope[:args].is_a?(Hash) ? envelope[:args].merge(envelope) : envelope
            outcome = Legion::Extensions::Transformer::Client.new.transform(payload: context, **request)
            Legion::Data.connection.transaction do
              dataset = Legion::Data::Model::Task.where(id: envelope[:task_id])
              dataset = dataset.for_update unless Legion::Data.connection.database_type == :sqlite
              current = dataset.first.values
              stopped = transformer_stopped(task: current)
              return stopped if stopped

              if current[:transformation_result]
                recorded = Legion::JSON.load(current[:transformation_result])
                return recorded.merge(task_id: current[:id], status: current[:status], durable: true, duplicate: true)
              end
              status = outcome[:success] ? task_status(name: :transformer_succeeded) : outcome.fetch(:status)
              changed = Legion::Data::TaskExecution.transition_task(
                task_id: envelope[:task_id], status: status, expected_status: current[:status],
                values: { transformation_result: outcome }
              )
              raise "transform task #{envelope[:task_id]} transition rejected: #{changed[:reason]}" unless changed[:changed]
              return outcome.merge(task_id: envelope[:task_id], durable: true) unless outcome[:success]

              target = envelope.merge(definition_version: outcome.fetch(:definition_version))
              transformer_check_dispatch!(envelope: target)
              transformer_dispatch(envelope: target, result: outcome[:result], persisted: true)
              outcome.merge(task_id: envelope[:task_id], durable: true)
            end
          end

          def transformer_stopped(task:)
            status = task[:status]
            unless task_terminal_status?(status: status)
              if task[:cancelled_at]
                status = task_status(name: :cancelled)
              elsif task[:deadline_at] && Time.parse(task[:deadline_at].to_s) <= Time.now
                status = task_status(name: :expired)
              end
              if status != task[:status]
                transition = Legion::Data::TaskExecution.transition_task(task_id: task[:id], status: status, expected_status: task[:status])
                status = transition.fetch(:task).fetch(:status)
              end
            end
            return unless task_terminal_status?(status: status) || status == task_status(name: :running)

            { success: [task_status(name: :completed), task_status(name: :multiplied)].include?(status),
              status: status, task_id: task[:id], duplicate: true, durable: true }
          end

          def transformer_check_dispatch!(envelope:)
            raise ArgumentError, 'task deadline has expired' if envelope[:deadline_at] && Time.parse(envelope[:deadline_at].to_s) <= Time.now

            target_id = Legion::Data.connected? && envelope[:function_id]
            explicit_target = envelope[:function].is_a?(String) && !envelope[:function].empty? &&
                              envelope[:runner_routing_key].is_a?(String) && !envelope[:runner_routing_key].empty?
            raise ArgumentError, 'target function_id or explicit function and runner_routing_key is required' unless target_id || explicit_target

            max_depth = task_execution_settings.fetch(:execution).fetch(:max_depth)
            raise ArgumentError, "task depth exceeds #{max_depth}" if envelope.fetch(:depth, 0).to_i > max_depth
          end

          def transformer_dispatch(envelope:, result:, persisted:)
            fields = task_execution_settings.fetch(:protocol).fetch(:metadata_fields).map(&:to_sym)
            metadata = envelope.slice(*fields).except(:attempt_id, :execution_token)
            if result.is_a?(Array)
              transformer_fanout(metadata: metadata, result: result, persisted: persisted)
            elsif persisted
              Legion::Data::TaskExecution.enqueue_dispatch(
                task_id: metadata[:task_id],
                **transformer_intent(options: metadata.merge(args: result), event_key: "transform:#{metadata[:task_id]}:#{metadata[:definition_version]}")
              )
              Legion::Data::TaskExecution.transition_task(task_id: metadata[:task_id], status: task_status(name: :queued),
                                                          expected_status: task_status(name: :transformer_succeeded), values: { function_args: result })
            else
              transformer_publish(options: metadata.merge(args: result))
            end
          end

          def transformer_fanout(metadata:, result:, persisted:)
            depth = metadata.fetch(:depth, 0).to_i + 1
            max_depth = task_execution_settings.fetch(:execution).fetch(:max_depth)
            raise ArgumentError, "fanout depth exceeds #{max_depth}" if depth > max_depth

            max_fanout = task_execution_settings.fetch(:execution).fetch(:max_fanout)
            raise ArgumentError, "transform output exceeds max_fanout #{max_fanout}" if result.length > max_fanout

            result.each_with_index do |args, index|
              child = metadata.except(:task_id, :message_id).merge(parent_id: metadata[:task_id], master_id: metadata[:master_id] || metadata[:task_id],
                                                                   depth: depth, args: args)
              if persisted
                key = "transform:#{metadata[:task_id]}:#{metadata[:definition_version]}:#{index}"
                child[:message_id] = key
                Legion::Data::TaskExecution.create_task(
                  values:          child.slice(*Legion::Data::Model::Task.columns).merge(status: task_status(name: :queued), function_args: args,
                                                                                         payload: child),
                  idempotency_key: key,
                  dispatch:        transformer_intent(options: child, event_key: key)
                )
              else
                transformer_publish(options: child)
              end
            end
            return unless persisted

            Legion::Data::TaskExecution.transition_task(task_id: metadata[:task_id], status: task_status(name: :multiplied),
                                                        expected_status: task_status(name: :transformer_succeeded))
          end

          def transformer_intent(options:, event_key:)
            type = options[:function_id] ? :dynamic : :task
            options = options.merge(routing_key: options.fetch(:runner_routing_key)) if type == :task
            { event_key: event_key, message_type: task_execution_settings.fetch(:message_types).fetch(type), options: options }
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
