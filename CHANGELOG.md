# Changelog

## [0.4.0] - 2026-10-30

### Breaking changes

#### Engine and registry APIs now require keyword arguments

This is a kwargs-only cutover with no positional compatibility shims. Direct engine callers and custom engine implementations must migrate; changing only the built-in engines is not sufficient for external integrations.

| API | Before 0.4.0 | 0.4.0 |
| --- | --- | --- |
| Render an engine | `engine.render(template, payload, **options)` | `engine.render(template: template, payload: payload, **options)` |
| Register an engine | `Registry.register(CustomEngine)` | `Registry.register(engine_class: CustomEngine)` |
| Fetch an engine | `Registry.fetch(:erb)` | `Registry.fetch(name: :erb)` |
| Detect an engine | `Registry.detect(template)` | `Registry.detect(template: template)` |
| Fetch a definition | `Definitions.fetch(name)` | `Definitions.fetch(name: name)` |

Custom engines must change `def render(template, payload, **opts)` to `def render(template:, payload:, **opts)`. Use `**` instead of `**opts` only when additional keywords are intentionally ignored. Existing positional calls or positional-only overrides can raise `ArgumentError` on the supported Ruby versions.

`Registry.reset!` and `Definitions.merge_options` are removed. Configure engine permissions through `extensions.transformer.allowed_engines`; pass per-call overrides as `engine_options:` to `Client#transform`, which merges them with named-definition options.

#### Configuration and execution behavior

- Named definitions move from `lex-transformer.definitions` to `extensions.transformer.definitions`. The old namespace is no longer read.
- Custom engines must be both registered and explicitly enabled by name in the Boolean `extensions.transformer.allowed_engines` map. Registration alone no longer grants permission to execute.
- ERB no longer executes by default, including when auto-detected from template markers. Administrator-owned templates require `extensions.transformer.allow_trusted_engines: true` and an enabled ERB engine grant. Do not enable this for untrusted templates.
- Rendered output must be a Hash or an Array of Hashes. String output must parse as JSON into one of those shapes; invalid JSON, scalar results, and mixed arrays now fail rather than passing through.
- A rendered Hash containing `success: false` is business data, not an engine failure signal. Custom engines must raise an exception to report rendering failure.
- `Client#transform_chain` returns the final rendered output in `result`, not the accumulated input/intermediate context. Templates must explicitly retain fields needed in the final output.
- The runner's `transform_chain` entry point is replaced by `transform(steps: ..., **payload)`. The standalone client still exposes `transform_chain(steps:, payload:)`. The old runner helper entry points `render_transformation`, `dispatch_transformed`, `dispatch_multiplied`, and `send_task` are removed.
- Named-definition conditions are enforced through Conditioner. Missing definitions, malformed rules, and condition-evaluation errors no longer silently pass.
- AMQP handoff uses `publish!`: rejected publication and persistence failures propagate instead of returning a successful handoff. A successful stage result means dispatch, not completion of the destination task.

### Changed
- Share one client/actor transformation pipeline with final-output-only chain dispatch and keyword-only engine APIs.
- Separate engine exceptions from rendered business data, preserving payloads containing `success: false`.
- Preserve arbitrary transport headers and business keys in the ERB `payload` Hash while exposing only valid, non-keyword Ruby locals.
- Load named definitions through `extensions.transformer` settings and use the real Conditioner `valid` contract; missing or malformed conditions never fail open.
- Normalize JSON-backed schema fields and supported type names; reject invalid JSON, scalar output, mixed fanout, and oversized fanout before publication.
- Preserve canonical policy, lineage, schema, engine, schedule, and correlation metadata across transformation handoffs.
- Replace execution transitions and outbox intents with ordinary Task model create/update operations, explicitly serialized JSON, and direct confirmed publication.
- Give fanout children distinct task/message identities and their own arguments; preserve cancellation, failure states, target routing, and lineage without execution-schema dependencies. Remove unmerged execution deadline enforcement.
- Report direct handoffs as nondurable even when task rows are persisted; publication failures raise and partial fanout is not transactionally replay-safe.
- Make ERB trusted-only and disabled by default, with configurable engine allowlist and explicit administrator opt-in.
- Move LLM retry/default policy and dynamic execution depth/fanout limits to extension settings and log all transformation failures.
- Register SDK defaults at startup and read live canonical extension policy without loader caches, bootstrap-on-read or custom settings accessors; preserve denied engines and validated execution limits.
- Use `Legion::Transport::Task::Protocol` immutable protocol/status identities; remove the obsolete `TaskProtocol` namespace.
- Require Settings 1.4.5, Data 1.11.0, Transport 1.4.32, and Conditioner 0.4.0; use released Transport in CI and pin the current Data and Conditioner companion PR revisions.
- Resolve local companion dependencies from existing extension and workspace checkouts.

### Fixed
- Leave legacy `running` tasks untouched without redispatching them, and treat legacy completed task states as successful duplicate deliveries.
- Keep `default_settings` in the root extension module in `transformer.rb`; remove the separate settings file and custom configuration helper, and restore the fixed `task.transform` queue name.

### Testing
- Replace fake Conditioner/settings results and no-op runner stubs with real client, SQLite persistence, and local transport boundary regressions.

## [0.3.8] - 2026-04-23

### Fixed
- Transport module: replace lazy `extend` pattern with standard eager `require` + `extend`, fixing `NameError: uninitialized constant Transport::Queues` when lex-transformer boots before `Legion::Extensions::Transport` is loaded (fixes #8)

## [0.3.7] - 2026-04-13

### Added
- `:engine` to `send_task` whitelist — transformer now forwards the explicit engine parameter from the relationship row to the downstream dispatch message

## [0.3.6] - 2026-03-30

### Changed
- update to rubocop-legion 0.1.7, resolve all offenses

## [0.3.5] - 2026-03-28

### Fixed
- Transport module: replace invalid `super` call in `self.build` with explicit `Legion::Extensions::Transport.instance_method(:build).bind(self).call`, fixing `NoMethodError: super: no superclass method 'build'` boot crash

## [0.3.4] - 2026-03-27

### Fixed
- Transport module: added `defined?` guard on `::Legion::Extensions::Transport` to prevent `uninitialized constant` errors during parallel extension boot

## [0.3.2] - 2026-03-23

### Changed
- LLM engine passes `caller:` identity to `Legion::LLM.chat` and `Legion::LLM.structured`; defaults to `{ extension: 'lex-transformer', mode: :transform }` when not provided by upstream caller (e.g. lex-synapse)

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
