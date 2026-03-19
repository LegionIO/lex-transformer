# frozen_string_literal: true

require_relative 'base'

module Legion
  module Extensions
    module Transformer
      module Engines
        class Liquid < Base
          def name
            :liquid
          end

          def render(template, payload, **_opts)
            require 'liquid'
            liquid_template = ::Liquid::Template.parse(template)
            liquid_template.render(stringify_keys(payload))
          end

          private

          def stringify_keys(hash)
            hash.each_with_object({}) do |(k, v), result|
              result[k.to_s] = v.is_a?(Hash) ? stringify_keys(v) : v
            end
          end
        end
      end
    end
  end
end
