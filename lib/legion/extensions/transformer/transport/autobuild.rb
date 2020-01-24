require 'legion/extensions/transport/autobuild'
require 'legion/extensions/conditioner/transport/exchanges/conditioner'

module Legion
  module Extensions
    module Transformer
      module Transport
        module AutoBuild
          extend Legion::Extensions::Transport::AutoBuild

          def self.e_to_q
            [{
                 from:        Legion::Extensions::Conditioner::Transport::Exchanges::Conditioner,
                 to:          'transformer',
                 routing_key: 'conditioner.succeeded'
             }]
          end
        end
      end
    end
  end
end
