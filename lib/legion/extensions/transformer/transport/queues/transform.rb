# frozen_string_literal: true

require_relative '../../settings'

module Legion
  module Extensions
    module Transformer
      module Transport
        module Queues
          class Transform < Legion::Transport::Queue
            include Legion::Extensions::Transformer::Helpers::Configuration

            def queue_name
              settings.fetch(:queue)
            end
          end
        end
      end
    end
  end
end
