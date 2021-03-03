require 'tilt'

module Legion::Extensions::Transformer
  module Runners
    module Transform
      def transform(transformation:, **payload)
        if transformation.include?('<%') || transformation.include?('%>')
          template = Tilt['erb'].new { transformation }
          variables = { **payload }
          variables[:crypt] = Legion::Crypt if transformation.include? 'crypt'
          variables[:settings] = Legion::Settings if transformation.include? 'settings'
          variables[:cache] = Legion::Cache if transformation.include? 'cache'
          if payload.key?(:task_id) && transformation.include?('task')
            variables[:task] = Legion::Data::Model::Task[payload[:task_id]]
          end

          payload[:args] = from_json(template.render(self, variables))
        else
          payload[:args] = from_json(transformation)
        end

        case payload[:args]
        when Hash
          unless payload[:task_id].nil?
            task_update(payload[:task_id], 'transformer.succeeded', function_args: payload[:args])
          end
          send_task(**payload)
          task_update(payload[:task_id], 'task.queued', use_database: false) unless payload[:task_id].nil?
        when Array
          payload[:args].each do |thing|
            new_payload = payload
            task = Legion::Runner::Status.generate_task_id(function_args: thing,
                                                           status:        'task.queued',
                                                           args:          thing,
                                                           **new_payload)
            new_payload[:task_id] = task[:task_id]
            new_payload[:args] = thing
            send_task(**new_payload)
          end
          unless payload[:task_id].nil?
            task_update(payload[:task_id],
                        'task.multiplied',
                        function_args: payload[:args])
          end
        end

        if payload[:debug] && payload.key?(:task_id)
          generate_task_log(task_id: payload[:task_id], function: 'transform', values: payload)
        end
        { success: true, **payload }
      end

      def send_task(**opts)
        payload = {}
        %i[task_id relationship_id trigger_function_id runner_class function_id function chain_id debug args].each do |thing| # rubocop:disable Layout/LineLength
          payload[thing] = opts[thing] if opts.key? thing
        end

        Legion::Extensions::Transformer::Transport::Messages::Message.new(**payload).publish
      end

      include Legion::Extensions::Helpers::Lex
      extend Legion::Extensions::Helpers::Task
    end
  end
end
