require 'legion/extensions/transformer/version'
require 'legion/extensions'

module Legion
  module Extensions
    module Transformer
      extend Legion::Extensions::Core

      def data_required?
        true
      end
    end
  end
end
