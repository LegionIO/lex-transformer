# frozen_string_literal: true

require 'legion/extensions/transport'
require_relative 'settings'

module Legion
  module Extensions
    module Transformer
      module Transport
        extend Legion::Extensions::Transport
        extend Legion::Settings::TaskExecution::Helper

        build

        def self.additional_e_to_q
          [{ to: Legion::Extensions::Transformer::Transport::Queues::Transform, routing_key: task_route(name: :transform) }]
        end
      end
    end
  end
end
