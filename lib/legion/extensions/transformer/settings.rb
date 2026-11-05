# frozen_string_literal: true

require 'legion/settings'
require 'legion/transport/task/protocol'
require 'legion/logging'

module Legion
  module Extensions
    module Transformer
      def self.default_settings
        {
          definitions:           {},
          allowed_engines:       { static: true, erb: true, liquid: true, jsonpath: true, llm: true },
          default_engine:        'static',
          template_engine:       'erb',
          template_markers:      ['<%', '%>'],
          trusted_engines:       ['erb'],
          allow_trusted_engines: false,
          queue:                 'task.transform',
          execution:             { max_depth: 100, max_fanout: 1000 },
          llm:                   { max_retries: 1, retry_delay_seconds: 1, caller: { extension: 'lex-transformer', mode: 'transform' } }
        }
      end

      module Helpers
        module Configuration
          include Legion::Transport::Task::Protocol::Helper
          include Legion::Logging::Helper

          private

          def transformer_execution_settings(execution:)
            raise ArgumentError, 'transformer execution settings must be a Hash' unless execution.is_a?(Hash)

            %i[max_depth max_fanout].each do |name|
              value = execution.fetch(name)
              raise ArgumentError, "transformer execution.#{name} must be a positive Integer" unless value.is_a?(Integer) && value.positive?
            end
            execution
          end
        end
      end
    end
  end
end

Legion::Settings.merge_settings(:extensions, transformer: Legion::Extensions::Transformer.default_settings)
