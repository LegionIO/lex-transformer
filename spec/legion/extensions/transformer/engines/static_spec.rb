# frozen_string_literal: true

require 'spec_helper'
require 'legion/extensions/transformer/engines/static'

RSpec.describe Legion::Extensions::Transformer::Engines::Static do
  subject(:engine) { described_class.new }

  describe '#name' do
    it { expect(engine.name).to eq(:static) }
  end

  describe '#render' do
    it 'returns template unchanged' do
      expect(engine.render('{"key":"value"}', { ignored: true })).to eq('{"key":"value"}')
    end
  end
end
