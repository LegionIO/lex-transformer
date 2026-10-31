# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Legion::Extensions::Transformer::Definitions do
  it 'loads JSON-backed definitions through the extension settings helper' do
    config = Legion::JSON.load('{"extensions":{"transformer":{"definitions":{"notice":{"transformation":"{}","engine":"static"}}}}}')
    Legion::Settings.with_overlay(config) do
      expect(described_class.fetch(name: 'notice')).to include(transformation: '{}', engine: 'static')
      expect(described_class.fetch(name: 'missing')).to be_nil
      expect(described_class.names).to eq([:notice])
    end
  end

  it 'does not hide a malformed definitions configuration' do
    Legion::Settings.with_overlay(extensions: { transformer: { definitions: 'invalid' } }) do
      expect { described_class.fetch(name: 'notice') }.to raise_error(ArgumentError, /must be a Hash/)
    end
  end
end
