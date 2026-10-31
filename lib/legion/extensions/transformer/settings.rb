# frozen_string_literal: true

require 'legion/settings'
require 'legion/settings/task_execution'
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
          llm:                   { max_retries: 1, retry_delay_seconds: 1, caller: { extension: 'lex-transformer', mode: 'transform' } }
        }
      end

      def self.register_settings
        loader = Legion::Settings.get
        return if @settings_loader.equal?(loader)

        Legion::Settings.merge_settings(:extensions, transformer: default_settings)
        @settings_loader = loader
      end

      module Helpers
        module Configuration
          include Legion::Settings::Helper
          include Legion::Settings::TaskExecution::Helper
          include Legion::Logging::Helper

          private

          def settings
            Legion::Extensions::Transformer.register_settings
            super
          end

          def derive_settings_segments
            [:transformer]
          end
        end
      end
    end
  end
end
