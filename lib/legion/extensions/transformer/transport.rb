module Legion::Extensions::Transformer
  module Transport
    extend Legion::Extensions::Transport

    def self.additional_e_to_q
      [
        {
          to:          Legion::Extensions::Transformer::Transport::Queues::Transform,
          routing_key: 'task.conditioner.succeeded'
        }, {
          to:          Legion::Extensions::Transformer::Transport::Queues::Transform,
          routing_key: 'task.subtask.transform'
        }
      ]
    end
  end
end
