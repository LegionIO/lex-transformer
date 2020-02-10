module Legion::Extensions::Transformer
  module Transport
    module AutoBuild
      extend Legion::Extensions::Transport::AutoBuild

      def self.additional_e_to_q
        [{from: Legion::Transport::Exchanges::Task,
          to: Legion::Extensions::Transformer::Transport::Queues::Transform,
          routing_key: 'task.conditioner.succeeded'}]
      end
    end
  end
end
