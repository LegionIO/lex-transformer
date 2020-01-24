require 'legion/extensions/actors/subscription'

module Legion
  module Extensions
    module Transformer
      module Actor
        class Transform < Legion::Extensions::Actors::Subscription
          def queue
            Legion::Extensions::Transformer::Transport::Queues::Transformer
          end

          def class_path
            'legion/extensions/transformer/runners/transform'
          end

          def runner_class
            Legion::Extensions::Transformer::Runners::Transform
          end

          def runner_method
            'transform'
          end
        end
      end
    end
  end
end