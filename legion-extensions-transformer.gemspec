lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'legion/extensions/transformer/version'

Gem::Specification.new do |spec|
  spec.name          = 'lex-transformer'
  spec.version       = Legion::Extensions::Transformer::VERSION
  spec.authors       = ['Miverson']
  spec.email         = ['matthewdiverson@gmail.com']

  spec.summary       = 'LEX-Transformer is used to transform payloads for the output'
  spec.description   = 'Runs transformer statements against tasks in a relationship'
  spec.homepage      = 'https://bitbucket.org/legion-io/lex-transformer'
  spec.license       = 'MIT'

  if spec.respond_to?(:metadata)
    spec.metadata['homepage_uri'] = spec.homepage
    spec.metadata['source_code_uri'] = 'https://bitbucket.org/legion-io/lex-transformer'
    spec.metadata['changelog_uri'] = 'https://bitbucket.org/legion-io/lex-transformer'
  else
    raise 'RubyGems 2.0 or newer is required to protect against ' \
      'public gem pushes.'
  end

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '~> 1.17'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rspec', '~> 3.0'

  spec.add_dependency 'legion-exceptions'
  spec.add_dependency 'legion-extensions'
end
