# frozen_string_literal: true

require 'spec_helper'
require 'legion/extensions/transformer/engines/registry'

RSpec.describe Legion::Extensions::Transformer::Engines::Registry do
  describe '.fetch' do
    it('finds erb by symbol') { expect(described_class.fetch(:erb)).to be_a(Legion::Extensions::Transformer::Engines::Erb) }
    it('finds erb by string') { expect(described_class.fetch('erb')).to be_a(Legion::Extensions::Transformer::Engines::Erb) }
    it('finds static by symbol') { expect(described_class.fetch(:static)).to be_a(Legion::Extensions::Transformer::Engines::Static) }
    it('finds liquid by symbol') { expect(described_class.fetch(:liquid)).to be_a(Legion::Extensions::Transformer::Engines::Liquid) }
    it('finds jsonpath by symbol') { expect(described_class.fetch(:jsonpath)).to be_a(Legion::Extensions::Transformer::Engines::Jsonpath) }
    it('finds llm by symbol') { expect(described_class.fetch(:llm)).to be_a(Legion::Extensions::Transformer::Engines::Llm) }
    it('raises for unknown') { expect { described_class.fetch(:unknown) }.to raise_error(ArgumentError, /Unknown engine/) }
  end

  describe '.detect' do
    it('detects ERB markers') { expect(described_class.detect('<%= foo %>')).to be_a(Legion::Extensions::Transformer::Engines::Erb) }
    it('defaults to static') { expect(described_class.detect('{"key":"value"}')).to be_a(Legion::Extensions::Transformer::Engines::Static) }
  end
end
