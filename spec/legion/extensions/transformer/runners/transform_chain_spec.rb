# frozen_string_literal: true

require 'spec_helper'
require 'tilt'
require 'json'

require 'legion/extensions/transformer/runners/transform'

RSpec.describe Legion::Extensions::Transformer::Runners::Transform, '#transform_chain' do
  let(:test_class) do
    klass = Class.new do
      include Legion::Extensions::Transformer::Runners::Transform

      def from_json(str)
        JSON.parse(str, symbolize_names: true)
      end

      # Stubs for methods called by transform_chain's underlying dispatch (not needed for chain)
      def dispatch_transformed(_payload); end

      def generate_task_log(**_opts); end
    end
    klass.new
  end

  describe '#transform_chain' do
    context 'single-step chain' do
      it 'returns success: true with rendered result merged into args' do
        steps = [{ transformation: '{"output":"done"}', engine: :static }]
        result = test_class.transform_chain(steps: steps, task_id: 1)
        expect(result[:success]).to be true
        expect(result[:args]).to eq({ output: 'done' })
      end
    end

    context 'multi-step chain' do
      it 'feeds output of one step as payload into the next step' do
        step1 = { transformation: '{"value":42}', engine: :static }
        step2 = { transformation: '{"doubled":"<%= value %>"}', engine: :erb }
        result = test_class.transform_chain(steps: [step1, step2])
        expect(result[:success]).to be true
        expect(result[:args]).to eq({ doubled: '42' })
      end
    end

    context 'chain with schema validation passing' do
      it 'proceeds normally when schema is satisfied' do
        schema = { required_keys: [:output] }
        steps = [{ transformation: '{"output":"ok"}', engine: :static, schema: schema }]
        result = test_class.transform_chain(steps: steps)
        expect(result[:success]).to be true
      end
    end

    context 'chain with schema validation failing mid-chain' do
      it 'returns success: false and validation_failed status' do
        schema = { required_keys: [:missing_key] }
        steps = [{ transformation: '{"output":"ok"}', engine: :static, schema: schema }]
        result = test_class.transform_chain(steps: steps)
        expect(result[:success]).to be false
        expect(result[:status]).to eq 'transformer.validation_failed'
        expect(result[:errors]).to be_an(Array)
        expect(result[:errors]).not_to be_empty
      end

      it 'stops processing after the failing step' do
        schema = { required_keys: [:missing_key] }
        step1 = { transformation: '{"output":"ok"}', engine: :static, schema: schema }
        step2 = { transformation: '{"should_not_run":"yes"}', engine: :static }
        result = test_class.transform_chain(steps: [step1, step2])
        expect(result[:success]).to be false
        expect(result).not_to have_key(:should_not_run)
      end
    end

    context 'chain with different engines per step' do
      it 'uses the specified engine for each step' do
        step1 = { transformation: '{"greeting":"hello"}', engine: :static }
        step2 = { transformation: '{"message":"<%= greeting %> world"}', engine: :erb }
        result = test_class.transform_chain(steps: [step1, step2])
        expect(result[:success]).to be true
        expect(result[:args]).to eq({ message: 'hello world' })
      end
    end

    context 'chain with no engine specified' do
      it 'auto-detects the engine' do
        steps = [{ transformation: '{"auto":"detected"}' }]
        result = test_class.transform_chain(steps: steps)
        expect(result[:success]).to be true
        expect(result[:args]).to eq({ auto: 'detected' })
      end
    end
  end
end
