# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'sequel'
require 'sequel/extensions/migration'
require 'legion/extensions/transformer/runners/transform'
require 'legion/transport/exchanges/task'

RSpec.describe Legion::Extensions::Transformer::Runners::Transform do
  subject(:runner) do
    stub_const('Legion::Extensions::Transformer::Runners::TransformHarness', Class.new do
      include Legion::Settings::Helper
      include Legion::Extensions::Transformer::Runners::Transform
    end).new
  end

  let(:target) { { function: 'deliver', runner_routing_key: 'test.receiver.deliver', runner_class: 'Test::Receiver' } }
  let(:received) { [] }

  before(:context) do
    @directory = Dir.mktmpdir('transformer-tasks')
    @database = Sequel.sqlite(File.join(@directory, 'tasks.db'))
    migrations = File.join(Gem.loaded_specs.fetch('legion-data').full_gem_path, 'lib/legion/data/migrations')
    Sequel::Migrator.run(@database, migrations)
    Sequel::Model.db = @database
    require 'legion/data/models/task'
  end

  after(:context) do
    @database.disconnect
    FileUtils.remove_entry(@directory)
  end

  before do
    Legion::Transport::Connection.setup
    @channel = Legion::Transport::Connection.session.create_channel
    @queue = @channel.queue_declare_without_recording_topology('transformer-persisted-target')
    @queue.bind('task', routing_key: 'test.receiver.deliver')
    @queue.subscribe(manual_ack: false) { |_delivery, _properties, body| received << Legion::JSON.load(body) }
  end

  after do
    @channel.close
    Legion::Transport::Local.reset!
  end

  around do |example|
    previous = Legion::Data::Connection.sequel
    previous_dataset = Legion::Data::Model::Task.dataset
    Legion::Data::Connection.sequel = @database
    Legion::Data::Model::Task.set_dataset(@database[:tasks])
    @database[:tasks].delete
    Legion::Settings.with_overlay(data: { connected: true }, transport: { messages: { encrypt: false } }) { example.run }
  ensure
    Legion::Data::Connection.sequel = previous
    Legion::Data::Model::Task.set_dataset(previous_dataset)
  end

  def task_create(**values)
    Legion::Data::Model::Task.create({ status: 'transformer.queued' }.merge(values)).values
  end

  it 'creates distinct fanout children and directly publishes their own identities and arguments' do
    parent = task_create
    first = runner.transform(transformation: '[{"id":1},{"id":2}]', task_id: parent[:id], message_id: 'parent-message', **target)
    children = @database[:tasks].where(parent_id: parent[:id]).order(:id).all
    expect(first).to include(success: true, durable: false)
    expect(children.size).to eq(2)
    expect(children.map { |child| Legion::JSON.load(child[:function_args]) }).to eq([{ id: 1 }, { id: 2 }])
    expect(children.map { |child| Legion::JSON.load(child[:payload])[:args] }).to eq([{ id: 1 }, { id: 2 }])
    expect(children).to all(include(status: 'task.queued', master_id: parent[:id], depth: 1))
    expect(received.map { |message| message[:args] }).to eq([{ id: 1 }, { id: 2 }])
    expect(received.map { |message| message[:task_id] }).to eq(children.map { |child| child[:id] })
    expect(received.map { |message| message[:message_id] }.uniq.size).to eq(2)
    expect(received.map { |message| message[:message_id] }).not_to include('parent-message')
    expect(@database[:tasks].where(id: parent[:id]).get(:status)).to eq('task.multiplied')

    second = runner.transform(transformation: '[{"id":3}]', task_id: parent[:id], **target)
    expect(second).to include(success: true, duplicate: true, status: 'task.multiplied')
    expect(received.size).to eq(2)
  end

  it 'preserves metadata and serializes only final chain output into the ordinary task row' do
    parent = task_create
    task = task_create(parent_id: parent[:id], master_id: parent[:id])
    metadata = { parent_id: parent[:id], master_id: parent[:id], principal_id: 'principal-1', principal_type: 'service',
                 worker_id: 'worker-1', tenant_id: 'tenant-1', correlation_id: 'correlation', source: 'scheduler',
                 schedule_id: 'schedule', occurrence_id: 'occurrence', depth: 1, schema: { required_keys: ['final'] }, engine_options: { custom: true } }
    outcome = runner.transform(steps:   [{ transformation: '{"initial":"input"}' }, { transformation: '{"final":"<%= initial %>"}' }],
                               task_id: task[:id], **metadata, **target)
    expect(outcome).to include(success: true, result: { final: 'input' }, durable: false)
    expect(received.size).to eq(1)
    expect(received.first).to include(metadata.merge(task_id: task[:id], args: { final: 'input' }))
    stored = Legion::Data::Model::Task[task[:id]].values
    expect(stored[:status]).to eq('task.queued')
    expect(Legion::JSON.load(stored[:function_args])).to eq(final: 'input')
    expect(Legion::JSON.load(stored[:payload])).to include(metadata.merge(definition_version: outcome[:definition_version]))
  end

  it 'keeps rendered identity and routing fields inside business arguments' do
    task = task_create
    outcome = runner.transform(transformation: '{"task_id":999,"function":"wrong","principal_id":"wrong"}',
                               task_id: task[:id], principal_id: 'trusted', **target)
    expect(outcome).to include(success: true)
    expect(received.first).to include(task_id: task[:id], function: 'deliver', principal_id: 'trusted',
                                      args: { task_id: 999, function: 'wrong', principal_id: 'wrong' })
  end

  it 'records schema failures as JSON without publishing a target' do
    task = task_create
    outcome = runner.transform(transformation: '{"id":"wrong"}', schema: { types: { id: 'integer' } }, task_id: task[:id], **target)
    expect(outcome).to include(success: false, status: 'transformer.validation_failed')
    expect(received).to be_empty
    stored = Legion::Data::Model::Task[task[:id]].values
    expect(stored[:status]).to eq('transformer.validation_failed')
    expect(Legion::JSON.load(stored[:results])).to include(success: false, status: 'transformer.validation_failed')
  end

  it 'records rendering errors without publishing a target' do
    task = task_create
    expect(runner.transform(transformation: '{broken', task_id: task[:id], **target)).to include(success: false, status: 'transformer.failed')
    expect(Legion::Data::Model::Task[task[:id]][:status]).to eq('transformer.failed')
    expect(received).to be_empty
  end

  it 'does not interfere with running or terminal target tasks' do
    %w[task.running task.failed task.completed task.cancelled].each do |status|
      task = task_create(status: status)
      expect(runner.transform(transformation: '{}', task_id: task[:id], **target)).to include(duplicate: true, status: status)
      expect(Legion::Data::Model::Task[task[:id]][:status]).to eq(status)
    end
    expect(received).to be_empty
  end

  it 'does not dispatch cancelled tasks' do
    task = task_create(cancelled_at: Time.now)
    expect(runner.transform(transformation: '{}', task_id: task[:id], **target)).to include(success: false, status: 'task.cancelled')
    expect(received).to be_empty
    expect(Legion::Data::Model::Task[task[:id]][:status]).to eq('task.cancelled')
  end

  it 'bounds fanout before creating any child' do
    task = task_create
    Legion::Settings.with_overlay(extensions: { transformer: { execution: { max_fanout: 1 } } }) do
      expect(runner.transform(transformation: '[{},{}]', task_id: task[:id], **target)).to include(success: false)
    end
    expect(@database[:tasks].where(parent_id: task[:id]).count).to eq(0)
    expect(received).to be_empty
  end

  it 'checks child depth before changing task rows or publishing' do
    task = task_create
    Legion::Settings.with_overlay(extensions: { transformer: { execution: { max_depth: 1 } } }) do
      expect { runner.transform(transformation: '[{}]', task_id: task[:id], depth: 1, **target) }
        .to raise_error(ArgumentError, 'fanout depth exceeds 1')
    end
    expect(Legion::Data::Model::Task[task[:id]][:status]).to eq('transformer.queued')
    expect(@database[:tasks].where(parent_id: task[:id]).count).to eq(0)
    expect(received).to be_empty
  end

  it 'raises rejected publication without pretending persisted rows guarantee delivery' do
    task = task_create
    @channel.close
    Legion::Transport::Local.reset!
    expect { runner.transform(transformation: '{}', task_id: task[:id], **target) }.to raise_error(Legion::Transport::PublishRejected)
    expect(Legion::Data::Model::Task[task[:id]][:status]).to eq('task.queued')
  end
end
