# frozen_string_literal: true

require_relative 'base'

module Legion
  module Extensions
    module Transformer
      module Engines
        class Static < Base
          def name
            :static
          end

          def render(template, _payload, **_opts)
            template
          end
        end
      end
    end
  end
end
