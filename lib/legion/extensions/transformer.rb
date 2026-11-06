# frozen_string_literal: true

require 'legion/extensions/transformer/version'
require 'legion/settings'

module Legion
  module Extensions
    module Transformer
      extend Legion::Extensions::Core if Legion::Extensions.const_defined? :Core, false

      def self.default_settings
        {
          definitions:           {},
          allowed_engines:       { static: true, erb: true, liquid: true, jsonpath: true, llm: true },
          default_engine:        'static',
          template_engine:       'erb',
          template_markers:      ['<%', '%>'],
          trusted_engines:       ['erb'],
          allow_trusted_engines: false,
          execution:             { max_depth: 100, max_fanout: 1000 },
          llm:                   { max_retries: 1, retry_delay_seconds: 1, caller: { extension: 'lex-transformer', mode: 'transform' } }
        }
      end

      def self.data_required?
        false
      end
    end
  end
end

Legion::Settings.merge_settings(:extensions, transformer: Legion::Extensions::Transformer.default_settings)

require_relative 'transformer/client'
