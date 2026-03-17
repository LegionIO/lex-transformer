# frozen_string_literal: true

require 'spec_helper'
require 'legion/extensions/transformer/engines/erb'

RSpec.describe Legion::Extensions::Transformer::Engines::Erb do
  subject(:engine) { described_class.new }

  describe '#name' do
    it { expect(engine.name).to eq(:erb) }
  end

  describe '#render' do
    it 'renders ERB template with variables' do
      result = engine.render('hello <%= name %>', { name: 'world' })
      expect(result).to eq('hello world')
    end

    it 'renders complex templates' do
      result = engine.render('{"key":"<%= value %>"}', { value: 'test' })
      expect(result).to eq('{"key":"test"}')
    end

    it 'handles templates without variables' do
      result = engine.render('static text', {})
      expect(result).to eq('static text')
    end
  end
end
