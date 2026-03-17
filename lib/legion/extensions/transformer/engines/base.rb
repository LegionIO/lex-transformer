# frozen_string_literal: true

module Legion
  module Extensions
    module Transformer
      module Engines
        class Base
          def render(template, payload)
            raise NotImplementedError, "#{self.class}#render must be implemented"
          end

          def name
            raise NotImplementedError, "#{self.class}#name must be implemented"
          end
        end
      end
    end
  end
end
