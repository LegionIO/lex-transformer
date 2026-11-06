# frozen_string_literal: true

require 'spec_helper'
require 'legion/extensions/transformer/engines/liquid'

RSpec.describe Legion::Extensions::Transformer::Engines::Liquid do
  subject(:engine) { described_class.new }

  describe '#name' do
    it { expect(engine.name).to eq(:liquid) }
  end

  describe '#render' do
    it 'renders liquid template with variables' do
      result = engine.render(template: 'hello {{ name }}', payload: { name: 'world' })
      expect(result).to eq('hello world')
    end

    it 'renders JSON output' do
      result = engine.render(template: '{"greeting":"{{ name }}"}', payload: { name: 'world' })
      expect(result).to eq('{"greeting":"world"}')
    end

    it 'handles nested variables' do
      result = engine.render(template: '{{ user.name }}', payload: { user: { name: 'alice' } })
      expect(result).to eq('alice')
    end

    it 'handles missing variables as empty string' do
      result = engine.render(template: 'hello {{ missing }}', payload: {})
      expect(result).to eq('hello ')
    end

    it 'handles liquid filters' do
      result = engine.render(template: '{{ name | upcase }}', payload: { name: 'world' })
      expect(result).to eq('WORLD')
    end
  end
end
