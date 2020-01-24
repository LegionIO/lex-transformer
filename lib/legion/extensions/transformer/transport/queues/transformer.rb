module Legion
  module Extensions
    module Transformer
      module Transport
        module Queues
          class Transformer < Legion::Transport::Queue
            def queue_name
              'transformer'
            end
          end
        end
      end
    end
  end
end
