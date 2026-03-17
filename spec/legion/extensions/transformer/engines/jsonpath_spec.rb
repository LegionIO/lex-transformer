# frozen_string_literal: true

require 'spec_helper'
require 'legion/extensions/transformer/engines/jsonpath'

RSpec.describe Legion::Extensions::Transformer::Engines::Jsonpath do
  subject(:engine) { described_class.new }

  describe '#name' do
    it { expect(engine.name).to eq(:jsonpath) }
  end

  describe '#render' do
    let(:payload) do
      {
        response: {
          code: 200,
          data: {
            users: [
              { name: 'alice', role: 'admin' },
              { name: 'bob', role: 'user' }
            ]
          }
        },
        status:   'ok'
      }
    end

    it 'extracts top-level key' do
      expect(engine.render('$.status', payload)).to eq('ok')
    end

    it 'extracts nested key' do
      expect(engine.render('$.response.code', payload)).to eq(200)
    end

    it 'extracts deeply nested value' do
      expect(engine.render('$.response.data.users', payload)).to be_an(Array)
      expect(engine.render('$.response.data.users', payload).size).to eq(2)
    end

    it 'extracts array element by index' do
      expect(engine.render('$.response.data.users.0.name', payload)).to eq('alice')
    end

    it 'returns nil for missing path' do
      expect(engine.render('$.nonexistent.path', payload)).to be_nil
    end

    it 'works without $ prefix' do
      expect(engine.render('status', payload)).to eq('ok')
    end

    it 'works with $.prefix' do
      expect(engine.render('$.status', payload)).to eq('ok')
    end
  end
end
