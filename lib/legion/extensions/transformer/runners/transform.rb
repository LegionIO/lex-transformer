require 'legion/transport/queue'

module Legion::Extensions::Transformer
  module Runners
    class Transform
      def self.transform(**payload)
        transform = Legion::Extensions::Transformer::Runners::Transform.new(payload)
        payload[:args] = Legion::JSON.load(transform.transform)

        task_update(payload[:task_id], 'transformer.succeeded') unless payload[:task_id].nil?

        message = Legion::Extensions::Transformer::Transport::Messages::Message.new(**payload)
        message.publish
        task_update(payload[:task_id], 'task.queued') unless payload[:task_id].nil?
        { success: true, **payload }
      rescue => e
        Legion::Logging.runner_exception(e, **payload)
        task_update(payload[:task_id], 'transformer.exception') unless payload[:task_id].nil?
      end

      def self.task_update(task_id, status = 'transformer.succeeded')
        Legion::Transport::Messages::TaskUpdate.new(task_id: task_id, status: status).publish
      end

      attr_accessor :task_id, :transformation, :values, :output
      def initialize(args)
        @task_id = args[:task_id]
        @transformation = args[:transformation]
        @args = args[:payload]||args
        @values = to_dotted_hash(args)
      end

      def transform
        @output = @transformation % @values
          # things to support long term
          # :count
        # @output = Legion::JSON.load(output)
      rescue KeyError => exception
        Legion::Logging.error(exception.message)
        Legion::Logging.debug(exception.backtrace.inspect)
        raise
      end

      def to_dotted_hash(hash, recursive_key = '')
        hash.each_with_object({}) do |(k, v), ret|
          key = recursive_key + k.to_s
          if v.is_a? Hash
            ret.merge! to_dotted_hash(v, key + '.')
          else
            ret[key.to_sym] = v
          end
        end
      end

      def message
        output = {}
        output[:args] = @output
        output[:relationship_id] = @args[:relationship_id]
        output[:chain_id] = @args[:chain_id]||nil
        output[:trigger_namespace_id] = @args[:trigger_namespace_id]||nil
        output[:trigger_function_id] = @args[:trigger_function_id]||nil
        output[:function_id] = @args[:function_id]||nil
        output[:function] = @args[:function]||nil
        output[:namespace_id] = @args[:namespace_id]||nil
        output[:conditions] = @args[:conditions]||nil
        output[:transformation] = @args[:transformation]||nil
        output[:task_id] = @args[:task_id]||nil
        output
      end
    end
  end
end