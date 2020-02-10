require 'legion/transport/queue'

module Legion
  module Extensions
    module Transformer
      module Runners
        class Transform
          def self.transform(payload)
            transform = Legion::Extensions::Transformer::Runners::Transform.new(payload[:payload])
            payload[:args] = Legion::JSON.load(transform.transform)

            task_update(payload[:task_id], 'transformer.succeeded') unless payload[:task_id].nil?

            queue = Legion::Data::Model::Namespace[payload[:payload][:namespace_id]].values[:queue]
            exchange = Legion::Data::Model::Namespace[payload[:payload][:namespace_id]].values[:exchange]
            if queue.is_a? String
              con = Legion::Transport::Queue.new(queue, {})
            elsif exchange.is_a? String
              con = Legion::Transport::Exchange.new(exchange, {})
            else
              raise Exception 'no queue or exchange available'
            end
            task_update(payload[:task_id], 'task.queued') unless payload[:task_id].nil?

            con.publish(Legion::JSON.dump(payload),content_type: 'application/json')
            con.close
          rescue => ex
            Legion::Logging.error 'LEX::Transformer::Runners::Transform had an exception'
            Legion::Logging.warn ex.message
            Legion::Logging.warn "payload: #{payload}"
            Legion::Logging.warn "values: #{transform.values}"
            Legion::Logging.warn ex.backtrace
            task_update(payload[:task_id], 'task.exception') unless payload[:task_id].nil?
          end

          def self.task_update(task_id, status = 'transformer.succeeded')
            Legion::Transport::Messages::TaskUpdate.new(task_id: task_id, status: status).publish
          end

          attr_accessor :task_id, :transformation, :values, :output
          def initialize(args)
            @task_id = args[:task_id]
            @transformation = args[:transformation]
            @values = to_dotted_hash(args)
          end

          def transform
            @output = @transformation % @values
            @output
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
        end
      end
    end
  end
end