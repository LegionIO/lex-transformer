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
      result = engine.render(template: 'hello <%= name %>', payload: { name: 'world' })
      expect(result).to eq('hello world')
    end

    it 'renders complex templates' do
      result = engine.render(template: '{"key":"<%= value %>"}', payload: { value: 'test' })
      expect(result).to eq('{"key":"test"}')
    end

    it 'retains arbitrary envelope keys without compiling them as Ruby locals' do
      input = { name: 'world', :'x-legion-version' => '2.0', 'trace-id' => 'trace', class: 'business-kind' }
      template = '<%= name %>/<%= payload[:"x-legion-version"] %>/<%= payload["trace-id"] %>/<%= payload[:class] %>'
      expect(engine.render(template: template, payload: input)).to eq('world/2.0/trace/business-kind')
    end

    it 'handles templates without variables' do
      result = engine.render(template: 'static text', payload: {})
      expect(result).to eq('static text')
    end
  end
end
