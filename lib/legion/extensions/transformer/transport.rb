# frozen_string_literal: true

module Legion
  module Extensions
    module Transformer
      module Transport
        def self.build
          unless @_extended
            return unless defined?(::Legion::Extensions::Transport)

            extend ::Legion::Extensions::Transport

            @_extended = true
          end
          super
        end

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
  end
end
