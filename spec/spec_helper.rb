# frozen_string_literal: true

ENV['LEGION_MODE'] = 'lite'

require 'simplecov'
SimpleCov.start

require 'bundler/setup'
require 'fileutils'
require 'legion/logging'
require 'legion/settings'
require 'legion/json'
require 'legion/extensions/transformer'
require 'legion/extensions/conditioner/client'

FileUtils.mkdir_p('tmp')
Legion::Logging.setup(log_file: 'tmp/spec.log', log_stdout: false, async: false)

RSpec.configure do |config|
  config.example_status_persistence_file_path = '.rspec_status'
  config.disable_monkey_patching!
  config.expect_with(:rspec) { |c| c.syntax = :expect }
  config.around do |example|
    Legion::Settings.with_overlay(extensions: { transformer: { allow_trusted_engines: true, llm: { retry_delay_seconds: 0 } } }) do
      example.run
    end
  end
end
