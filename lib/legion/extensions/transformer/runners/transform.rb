require 'tilt'

module Legion::Extensions::Transformer
  module Runners
    class Transform
      extend Legion::Extensions::Helpers::Lex
      extend Legion::Extensions::Helpers::Task

      def self.transform(transformation:, **payload)
        template = Tilt['erb'].new { transformation }
        variables = { **payload }
        variables[:crypt] = Legion::Crypt if transformation.include? 'crypt'
        variables[:settings] = Legion::Settings if transformation.include? 'settings'
        variables[:cache] = Legion::Cache if transformation.include? 'cache'
        variables[:task] = Legion::Data::Model::Task[payload[:task_id]] if payload.has_key?(:task_id) && transformation.include?('task')


        payload[:args] = from_json(template.render( self, variables ))
        if payload[:args].is_a? Hash
          task_update(payload[:task_id], 'transformer.succeeded', function_args: payload[:args]) unless payload[:task_id].nil?
          send_task(payload)
        elsif payload[:args].is_a? Array
          payload[:args].each do |thing|
            new_payload = payload
            task = Legion::Runner::Status.generate_task_id(function_args: thing, status: 'task.queued', args: thing, **new_payload)
            new_payload[:task_id] = task[:task_id]
            new_payload[:args] = thing
            send_task(**new_payload)
          end
          task_update(payload[:task_id], 'task.multiplied', function_args: payload[:args]) unless payload[:task_id].nil?
        end

        task_update(payload[:task_id], 'task.queued') unless payload[:task_id].nil?
        if payload[:debug] && payload.has_key?(:task_id)
          generate_task_log(task_id: payload[:task_id], function: 'transform', values: payload)
        end
        { success: true, **payload }
      # rescue => ex
        # task_update(payload[:task_id], 'transformer.exception') unless payload[:task_id].nil?
        # raise ex
      end

      def self.send_task(**opts)
        payload = {}
        [:task_id, :relationship_id, :trigger_function_id, :runner_class, :function_id, :function, :chain_id, :debug, :args].each do |thing|
          payload[thing] = opts[thing] if opts.has_key? thing
        end

        Legion::Extensions::Transformer::Transport::Messages::Message.new(**payload).publish
      end
    end
  end
end