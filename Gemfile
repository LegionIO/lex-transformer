# frozen_string_literal: true

source 'https://rubygems.org'

gemspec

companion_root = File.expand_path('.ci-dependencies', __dir__)
companion_root = File.expand_path('..', __dir__) unless Dir.exist?(companion_root)
%w[legion-settings legion-data legion-transport lex-conditioner].each do |name|
  path = File.join(companion_root, name)
  gem name, path: path if File.file?(File.join(path, "#{name}.gemspec"))
end

group :test do
  gem 'base64'
  gem 'liquid', '~> 5.0'
  gem 'rake'
  gem 'rspec', '~> 3.13'
  gem 'rspec_junit_formatter'
  gem 'rubocop', '~> 1.75'
  gem 'rubocop-legion', '~> 0.1'
  gem 'rubocop-rspec'
  gem 'simplecov'
  gem 'sqlite3'
end
