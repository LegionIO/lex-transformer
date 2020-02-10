module Legion::Extensions::Transformer
  module Transport
    module Queues
      class Transform < Legion::Transport::Queue
        def queue_name
          'task.transform'
        end
      end
    end
  end
end
