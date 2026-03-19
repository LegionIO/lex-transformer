# frozen_string_literal: true

require 'spec_helper'
require 'legion/extensions/transformer/definitions'

# Stub Legion::Settings for testing
module Legion
  module Settings
    DEFINITIONS = {
      'summarize_logs' => {
        'transformation' => 'Summarize these logs',
        'engine'         => 'llm',
        'engine_options' => { 'model' => 'ollama/llama3', 'temperature' => 0.1 },
        'schema'         => { 'required_keys' => %w[summary status] }
      },
      'extract_name'   => {
        'transformation' => '{"name":"<%= full_name %>"}',
        'engine'         => 'erb'
      }
    }.freeze

    def self.dig(*keys)
      result = { 'lex-transformer' => { 'definitions' => DEFINITIONS } }
      keys.each { |k| result = result.is_a?(Hash) ? result[k] : nil }
      result
    end
  end
end

RSpec.describe Legion::Extensions::Transformer::Definitions do
  describe '.fetch' do
    it 'returns the definition hash for a known name' do
      defn = described_class.fetch('summarize_logs')
      expect(defn).to be_a(Hash)
      expect(defn[:transformation]).to eq('Summarize these logs')
      expect(defn[:engine]).to eq(:llm)
    end

    it 'symbolizes engine_options keys' do
      defn = described_class.fetch('summarize_logs')
      expect(defn[:engine_options]).to include(model: 'ollama/llama3')
      expect(defn[:engine_options]).to include(temperature: 0.1)
    end

    it 'returns nil for unknown names' do
      expect(described_class.fetch('nonexistent')).to be_nil
    end

    it 'returns schema from definition' do
      defn = described_class.fetch('summarize_logs')
      expect(defn[:schema]).to eq('required_keys' => %w[summary status])
    end

    it 'handles definitions without engine_options' do
      defn = described_class.fetch('extract_name')
      expect(defn[:engine_options]).to eq({})
    end
  end

  describe '.names' do
    it 'returns all definition names' do
      names = described_class.names
      expect(names).to include('summarize_logs', 'extract_name')
    end
  end

  describe '.merge_options' do
    it 'merges definition engine_options with overrides (overrides win)' do
      defn = described_class.fetch('summarize_logs')
      merged = described_class.merge_options(defn, model: 'claude-sonnet-4-20250514')
      expect(merged[:model]).to eq('claude-sonnet-4-20250514')
      expect(merged[:temperature]).to eq(0.1)
    end

    it 'returns overrides when definition has no engine_options' do
      defn = described_class.fetch('extract_name')
      merged = described_class.merge_options(defn, model: 'test')
      expect(merged[:model]).to eq('test')
    end
  end
end
