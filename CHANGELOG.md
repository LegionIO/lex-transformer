# Changelog

## [0.3.1] - 2026-03-22

### Changed
- Add sub-gem runtime dependencies: legion-cache, legion-crypt, legion-data, legion-json, legion-logging, legion-settings, legion-transport
- Replace inline Legion::Logging and Legion::JSON stubs in spec_helper with real sub-gem helpers
- Build Helpers::Lex stub from real sub-gem helper modules in spec_helper
- Add Actors::Subscription and Helpers::Task stubs to spec_helper for actor load-time resolution
- Remove redundant inline Helpers::Lex/Task stubs from runner spec files

## [0.3.0] - 2026-03-19

### Added
- LLM engine error handling with categorized retry (timeout/network retry, auth errors raise, provider errors return failure)
- LLM engine model/provider/temperature/system_prompt kwargs via `engine_options`
- LLM engine structured output support (`structured: true` + `schema:`)
- LLM engine JSON response validation with correction prompt on retry
- Settings-based LLM defaults (`lex-transformer.llm.*`)
- Named transform definitions via Settings (`lex-transformer.definitions.*`)
- `Definitions` class for Settings-based definition lookup
- `name:` parameter on `Client#transform` for named definition execution
- `engine_options:` parameter on `Client#transform` and `Client#transform_chain`
- Conditioner integration for named definitions with conditions
- LLM failure hash passthrough (no dispatch on engine failure)
- Integration specs for LLM engine with client, chain, and named definitions

### Changed
- All engine `render` signatures accept `**opts` (backward-compatible, non-LLM engines ignore)

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
