# frozen_string_literal: true

source 'https://rubygems.org'

gemspec

%w[legion-settings legion-data legion-transport lex-conditioner].each do |name|
  paths = [File.expand_path(".ci-dependencies/#{name}", __dir__),
           File.expand_path("../#{name}", __dir__), File.expand_path("../../#{name}", __dir__)]
  path = paths.find { |candidate| File.file?(File.join(candidate, "#{name}.gemspec")) }
  gem name, path: path if path
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
