# frozen_string_literal: true

require 'spec_helper'

module Legion
  module Extensions
    module Transformer
      module Transport
        module Messages
          unless defined?(Legion::Extensions::Transformer::Transport::Messages::Message)
            class Message
              def initialize(**); end

              def publish; end
            end
          end
        end
      end
    end
  end
end

require 'legion/extensions/transformer/runners/transform'

RSpec.describe Legion::Extensions::Transformer::Runners::Transform do
  let(:test_class) do
    Class.new do
      include Legion::Extensions::Transformer::Runners::Transform

      def task_update(*_args, **_opts); end
      def generate_task_log(**_opts); end

      def from_json(str)
        Legion::JSON.load(str)
      rescue StandardError
        str
      end
    end
  end

  subject { test_class.new }

  describe '#send_task' do
    it 'includes engine in the forwarded payload' do
      message_double = double('Message', publish: true)
      allow(Legion::Extensions::Transformer::Transport::Messages::Message).to receive(:new).and_return(message_double)

      opts = {
        task_id:         1,
        relationship_id: 2,
        function_id:     3,
        function:        'transform',
        chain_id:        4,
        engine:          'llm',
        args:            { work_item: { title: 'test' } }
      }

      subject.send_task(**opts)

      expect(Legion::Extensions::Transformer::Transport::Messages::Message).to have_received(:new) do |**args|
        expect(args[:engine]).to eq('llm')
      end
    end

    it 'does not include engine when not present in payload' do
      message_double = double('Message', publish: true)
      allow(Legion::Extensions::Transformer::Transport::Messages::Message).to receive(:new).and_return(message_double)

      opts = {
        task_id:         1,
        relationship_id: 2,
        function_id:     3,
        function:        'transform',
        chain_id:        4,
        args:            { work_item: { title: 'test' } }
      }

      subject.send_task(**opts)

      expect(Legion::Extensions::Transformer::Transport::Messages::Message).to have_received(:new) do |**args|
        expect(args).not_to have_key(:engine)
      end
    end
  end
end
