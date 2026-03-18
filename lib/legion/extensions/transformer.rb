# frozen_string_literal: true

require 'legion/extensions/transformer/version'
require_relative 'transformer/client'

module Legion
  module Extensions
    module Transformer
      extend Legion::Extensions::Core if Legion::Extensions.const_defined? :Core

      def self.data_required?
        true
      end

      def data_required?
        true
      end
    end
  end
end
