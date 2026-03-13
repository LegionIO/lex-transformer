# frozen_string_literal: true

module Legion
  module Extensions
    module Transformer
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
  end
end
