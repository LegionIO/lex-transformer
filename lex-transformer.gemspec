lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'legion/extensions/transformer/version'

Gem::Specification.new do |spec|
  spec.name          = 'lex-transformer'
  spec.version       = Legion::Extensions::Transformer::VERSION
  spec.authors       = ['Esity']
  spec.email         = ['matthewdiverson@gmail.com']

  spec.summary       = 'LEX-Transformer is used to transform payloads for the output'
  spec.description   = 'Runs transformer statements against tasks in a relationship'
  spec.homepage      = 'https://github.com/LegionIO/lex-transformer'
  spec.license       = 'MIT'
  spec.required_ruby_version = '>= 3.4'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/LegionIO/lex-transformer'
  spec.metadata['documentation_uri'] = 'https://github.com/LegionIO/lex-transformer'
  spec.metadata['changelog_uri'] = 'https://github.com/LegionIO/lex-transformer'
  spec.metadata['bug_tracker_uri'] = 'https://github.com/LegionIO/lex-transformer/issues'

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.require_paths = ['lib']

  spec.add_dependency 'tilt', '>= 2.3'

  spec.add_development_dependency 'bundler', '>= 2'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'rubocop'
end
