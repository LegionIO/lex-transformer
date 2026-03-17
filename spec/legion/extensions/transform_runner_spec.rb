# frozen_string_literal: true

require 'spec_helper'
require 'tilt'
require 'json'

# Stub framework helpers that the runner includes at load time
module Legion
  module Extensions
    module Helpers
      module Lex; end
      module Task; end
    end
  end
end

require 'legion/extensions/transformer/runners/transform'

RSpec.describe Legion::Extensions::Transformer::Runners::Transform do
  let(:test_class) do
    klass = Class.new do
      include Legion::Extensions::Transformer::Runners::Transform

      def from_json(str)
        JSON.parse(str, symbolize_names: true)
      end
    end
    klass.new
  end

  describe '#render_transformation' do
    it 'renders a static JSON transformation' do
      result = test_class.render_transformation('{"key":"value"}', {})
      expect(result).to eq({ key: 'value' })
    end

    it 'renders an ERB transformation with payload variables' do
      template = '{"greeting":"hello <%= name %>"}'
      result = test_class.render_transformation(template, { name: 'world' })
      expect(result).to eq({ greeting: 'hello world' })
    end

    it 'renders ERB with nested payload access' do
      template = '{"status":"<%= status_code %>"}'
      result = test_class.render_transformation(template, { status_code: 200 })
      expect(result).to eq({ status: '200' })
    end

    it 'handles transformation without ERB markers as static JSON' do
      result = test_class.render_transformation('{"static":true}', { ignored: 'data' })
      expect(result).to eq({ static: true })
    end
  end

  describe '#build_template_variables' do
    it 'includes payload keys' do
      result = test_class.build_template_variables('simple', { key: 'val' })
      expect(result[:key]).to eq('val')
    end

    it 'does not include crypt when not in template' do
      result = test_class.build_template_variables('no special', {})
      expect(result).not_to have_key(:crypt)
    end

    it 'does not include settings when not in template' do
      result = test_class.build_template_variables('no special', {})
      expect(result).not_to have_key(:settings)
    end

    it 'does not include cache when not in template' do
      result = test_class.build_template_variables('no special', {})
      expect(result).not_to have_key(:cache)
    end
  end
end
