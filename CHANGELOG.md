# Changelog

## [0.2.1] - 2026-03-17

### Added
- LLM transform engine (`engines/llm.rb`) — provider-agnostic natural language transformation via `Legion::LLM.chat`
- Registered as `:llm` in engine registry (explicit only, no auto-detection)

## [0.2.0] - 2026-03-17

### Added
- Pluggable engine system with abstract `Engines::Base` and `Engines::Registry`
- 4 template engines: ERB (extracted from runner), Static (JSON passthrough), Liquid, JSONPath (dot-notation extraction)
- `Engines::Registry.detect` auto-selects ERB or static engine based on template content
- `render_transformation` accepts optional `engine:` keyword to force a specific engine
- `Helpers::SchemaValidator` validates transformed output against declared schemas (required keys, type checks)
- `transform` accepts optional `schema:` parameter for post-render validation
- `transform_chain` method for sequential multi-step pipelines with per-step engine selection and schema validation
- Standalone `Client` class for framework-independent usage with `transform` and `transform_chain` methods
- SimpleCov coverage reporting
- Modern packaging: grouped test dependencies, `require_relative` in gemspec, `rubocop-rspec`

### Fixed
- `dispatch_multiplied` payload mutation bug: `new_payload = payload` replaced with `new_payload = payload.dup`
- Spec filename typo: `tranformer_spec.rb` renamed to `transformer_spec.rb`

### Changed
- ERB rendering logic extracted from runner into `Engines::Erb` class
- `build_template_variables` moved to `Engines::Erb` as private `build_variables`
- Runner no longer directly requires `tilt` (delegated to `Engines::Erb`)

## [0.1.4] - 2026-03-13

### Added
- Initial release
