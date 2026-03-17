# frozen_string_literal: true

require_relative 'base'

module Legion
  module Extensions
    module Transformer
      module Engines
        class Jsonpath < Base
          def name
            :jsonpath
          end

          def render(expression, payload)
            extract(expression, payload)
          end

          private

          def extract(path, data)
            path = path.delete_prefix('$.') if path.start_with?('$.')
            segments = path.split('.')
            result = data
            segments.each do |segment|
              case result
              when Hash
                key = result.key?(segment.to_sym) ? segment.to_sym : segment
                result = result[key]
              when Array
                result = result[segment.to_i]
              else
                return nil
              end
            end
            result
          end
        end
      end
    end
  end
end
