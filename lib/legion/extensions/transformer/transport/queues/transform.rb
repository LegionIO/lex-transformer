# frozen_string_literal: true

require_relative '../../settings'

module Legion
  module Extensions
    module Transformer
      module Transport
        module Queues
          class Transform < Legion::Transport::Queue
            def queue_name
              Legion::Settings[:extensions][:transformer][:queue]
            end
          end
        end
      end
    end
  end
end
