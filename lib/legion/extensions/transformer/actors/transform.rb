require 'legion/extensions/actors/subscription'

module Legion
  module Extensions
    module Transformer
      module Actor
        class Transform < Legion::Extensions::Actors::Subscription
          def runner_function
            'transform'
          end
        end
      end
    end
  end
end