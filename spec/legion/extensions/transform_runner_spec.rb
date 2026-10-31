# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'sequel'
require 'sequel/extensions/migration'
require 'legion/extensions/transformer/runners/transform'

RSpec.describe Legion::Extensions::Transformer::Runners::Transform do
  subject(:runner) { Object.new.extend(described_class) }

  let(:target) { { function: 'deliver', runner_routing_key: 'test.receiver.deliver', runner_class: 'Test::Receiver' } }

  before(:context) do
    @directory = Dir.mktmpdir('transformer-replay')
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

  around do |example|
    previous = Legion::Data::Connection.sequel
    previous_dataset = Legion::Data::Model::Task.dataset
    Legion::Data::Connection.sequel = @database
    Legion::Data::Model::Task.set_dataset(@database[:tasks])
    @database[:task_dispatches].delete
    @database[:task_attempts].delete
    @database[:tasks].delete
    Legion::Settings.with_overlay(data: { connected: true }) { example.run }
  ensure
    Legion::Data::Connection.sequel = previous
    Legion::Data::Model::Task.set_dataset(previous_dataset)
  end

  def task_create(**values)
    Legion::Data::TaskExecution.create_task(values: { status: 'transformer.queued' }.merge(values), idempotency_key: SecureRandom.uuid).fetch(:task)
  end

  it 'replays fanout without reinterpreting durable state through local policy or obsolete identity overrides' do
    parent = task_create
    first = runner.transform(transformation: '[{"id":1},{"id":2}]', task_id: parent[:id], **target)
    second = Legion::Settings.with_overlay(
      task_execution: { statuses: { multiplied: 'local.multiplied', queued: 'local.queued' } },
      extensions:     { transformer: { execution: { max_fanout: 1 } } }
    ) do
      runner.transform(transformation: '[{"id":3}]', task_id: parent[:id], **target)
    end
    expect(first).to include(success: true, durable: true)
    expect(second).to include(success: true, duplicate: true, status: 'task.multiplied')
    expect(@database[:tasks].where(parent_id: parent[:id]).count).to eq(2)
    dispatches = Legion::Data::TaskExecution.claim_dispatches(owner: 'spec-relay')
    expect(dispatches.map { |dispatch| dispatch[:options][:args] }).to contain_exactly({ id: 1 }, { id: 2 })
    expect(dispatches.map { |dispatch| dispatch[:options][:task_id] }).to match_array(@database[:tasks].where(parent_id: parent[:id]).select_map(:id))
  end

  it 'reuses recorded output and revision despite changed definitions and obsolete terminal status overrides' do
    task = task_create
    first = runner.transform(transformation: '{"value":"original"}', task_id: task[:id], **target)
    second = Legion::Settings.with_overlay(task_execution: { statuses: { completed: 'task.queued' } }) do
      runner.transform(transformation: '{"value":"changed"}', task_id: task[:id], **target)
    end
    expect(second).to include(result: { value: 'original' }, definition_version: first[:definition_version])
    expect(@database[:task_dispatches].where(task_id: task[:id]).count).to eq(1)
  end

  it 'preserves policy and lineage while dispatching only final chain output' do
    parent = task_create
    task = task_create(parent_id: parent[:id], master_id: parent[:id])
    metadata = { parent_id: parent[:id], master_id: parent[:id], principal_id: 'principal-1', principal_type: 'service',
                 worker_id: 'worker-1', tenant_id: 'tenant-1', correlation_id: 'correlation', source: 'scheduler',
                 schedule_id: 'schedule', occurrence_id: 'occurrence', depth: 1, schema: { required_keys: ['final'] }, engine_options: { custom: true } }
    outcome = runner.transform(steps:   [{ transformation: '{"initial":"input"}' }, { transformation: '{"final":"<%= initial %>"}' }],
                               task_id: task[:id], **metadata, **target)
    expect(outcome).to include(success: true, result: { final: 'input' })
    dispatches = Legion::Data::TaskExecution.claim_dispatches(owner: 'spec-relay')
    expect(dispatches.size).to eq(1)
    expect(dispatches.first[:options]).to include(metadata.merge(task_id: task[:id], args: { final: 'input' }))
    expect(@database[:tasks].where(id: task[:id]).get(:status)).to eq('task.queued')
  end

  it 'records schema failure without enqueueing a target' do
    task = task_create
    result = runner.transform(transformation: '{"id":"wrong"}', schema: { types: { id: 'integer' } }, task_id: task[:id], **target)
    expect(result).to include(success: false, status: 'transformer.validation_failed')
    expect(@database[:task_dispatches].count).to eq(0)
    expect(@database[:tasks].where(id: task[:id]).get(:status)).to eq('transformer.validation_failed')
  end

  it 'does not reset an owned target retry when a completed transformation is replayed' do
    task = task_create
    runner.transform(transformation: '{"value":"original"}', task_id: task[:id], **target)
    claim = Legion::Data::TaskExecution.claim_task(task_id: task[:id], owner: 'target')
    Legion::Data::TaskExecution.complete_task(task_id: task[:id], token: claim[:token], status: 'task.failed', result: { success: false })
    Legion::Data::TaskExecution.transition_task(task_id: task[:id], token: claim[:token], status: 'task.retry_pending')
    before_replay = @database[:tasks].where(id: task[:id]).first
    replay = runner.transform(transformation: '{"value":"changed"}', task_id: task[:id], **target)
    expect(replay).to include(success: true, duplicate: true, status: 'task.retry_pending', result: { value: 'original' })
    expect(@database[:tasks].where(id: task[:id]).first).to eq(before_replay)
    expect(@database[:task_dispatches].count).to eq(1)
  end

  it 'does not interfere with a target execution claim on stage redelivery' do
    task = task_create
    runner.transform(transformation: '{}', task_id: task[:id], **target)
    claim = Legion::Data::TaskExecution.claim_task(task_id: task[:id], owner: 'target')
    runner.transform(transformation: '{"value":"changed"}', task_id: task[:id], **target)
    expect(@database[:tasks].where(id: task[:id]).first).to include(status: 'task.running', execution_token: claim[:token])
    expect(@database[:task_dispatches].count).to eq(1)
  end

  it 'does not dispatch cancelled tasks' do
    task = task_create(cancelled_at: Time.now)
    expect(runner.transform(transformation: '{}', task_id: task[:id], **target)).to include(success: false, status: 'task.cancelled')
    expect(@database[:task_dispatches].count).to eq(0)
    expect(@database[:tasks].where(id: task[:id]).get(:status)).to eq('task.cancelled')
  end

  it 'bounds fanout before creating any child' do
    task = task_create
    Legion::Settings.with_overlay(extensions: { transformer: { execution: { max_fanout: 1 } } }) do
      expect(runner.transform(transformation: '[{},{}]', task_id: task[:id], **target)).to include(success: false)
    end
    expect(@database[:tasks].where(parent_id: task[:id]).count).to eq(0)
    expect(@database[:task_dispatches].count).to eq(0)
  end

  it 'rolls back the stage outcome and fanout when children would exceed the local depth limit' do
    task = task_create
    Legion::Settings.with_overlay(extensions: { transformer: { execution: { max_depth: 1 } } }) do
      expect do
        runner.transform(transformation: '[{}]', task_id: task[:id], depth: 1, **target)
      end.to raise_error(Sequel::DatabaseError)
    end
    expect(@database[:tasks].where(id: task[:id]).first).to include(status: 'transformer.queued', transformation_result: nil)
    expect(@database[:tasks].where(parent_id: task[:id]).count).to eq(0)
    expect(@database[:task_dispatches].count).to eq(0)

    Legion::Settings.with_overlay(extensions: { transformer: { execution: { max_depth: 2 } } }) do
      expect(runner.transform(transformation: '[{}]', task_id: task[:id], depth: 1, **target))
        .to include(success: true, durable: true)
    end
    expect(@database[:tasks].where(id: task[:id]).get(:status)).to eq('task.multiplied')
    expect(@database[:tasks].where(parent_id: task[:id]).select_map(:depth)).to eq([2])
    expect(@database[:task_dispatches].count).to eq(1)
  end
end
