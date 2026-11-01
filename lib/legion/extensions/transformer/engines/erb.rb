# frozen_string_literal: true

require 'tilt'
require_relative 'base'
require_relative '../settings'

module Legion
  module Extensions
    module Transformer
      module Engines
        class Erb < Base
          RESERVED_LOCALS = %w[
            alias and begin break case class def do else elsif end ensure false for if in module next nil not or
            redo rescue retry return self super then true undef unless until when while yield __FILE__ __LINE__ __ENCODING__
            _1 _2 _3 _4 _5 _6 _7 _8 _9
          ].freeze

          def name
            :erb
          end

          def render(template:, payload:, **)
            raise ArgumentError, 'ERB requires trusted administrator-owned templates' unless Legion::Settings[:extensions][:transformer][:allow_trusted_engines]

            tilt_template = Tilt['erb'].new { template }
            variables = build_variables(template, payload)
            tilt_template.render(Object.new, variables)
          end

          private

          def build_variables(template, payload)
            variables = payload.each_with_object({}) do |(key, value), locals|
              name = key.to_s
              next unless /\A[a-z_][a-zA-Z_0-9]*\z/.match?(name)
              next if RESERVED_LOCALS.include?(name)

              locals[name.to_sym] = value
            end
            variables[:payload] = payload
            variables[:crypt] = Legion::Crypt if defined?(Legion::Crypt) && template.include?('crypt')
            variables[:settings] = Legion::Settings if defined?(Legion::Settings) && template.include?('settings')
            variables[:cache] = Legion::Cache if defined?(Legion::Cache) && template.include?('cache')
            if payload.key?(:task_id) && template.include?('task') && defined?(Legion::Data::Model::Task)
              variables[:task] = Legion::Data::Model::Task[payload[:task_id]]&.values
            end
            variables
          end
        end
      end
    end
  end
end
