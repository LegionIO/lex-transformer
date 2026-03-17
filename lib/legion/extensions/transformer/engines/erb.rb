# frozen_string_literal: true

require 'tilt'
require_relative 'base'

module Legion
  module Extensions
    module Transformer
      module Engines
        class Erb < Base
          def name
            :erb
          end

          def render(template, payload)
            tilt_template = Tilt['erb'].new { template }
            variables = build_variables(template, payload)
            tilt_template.render(Object.new, variables)
          end

          private

          def build_variables(template, payload)
            variables = { **payload }
            variables[:crypt] = Legion::Crypt if defined?(Legion::Crypt) && template.include?('crypt')
            variables[:settings] = Legion::Settings if defined?(Legion::Settings) && template.include?('settings')
            variables[:cache] = Legion::Cache if defined?(Legion::Cache) && template.include?('cache')
            if payload.key?(:task_id) && template.include?('task') && defined?(Legion::Data::Model::Task)
              variables[:task] = Legion::Data::Model::Task[payload[:task_id]]
            end
            variables
          end
        end
      end
    end
  end
end
