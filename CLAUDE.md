# lex-transformer: Payload Transformation Engine for LegionIO

**Repository Level 3 Documentation**
- **Parent**: `/Users/miverso2/rubymine/legion/extensions-core/CLAUDE.md`
- **Grandparent**: `/Users/miverso2/rubymine/legion/CLAUDE.md`

## Purpose

Legion Extension that transforms task payloads between services in a relationship chain. Uses pluggable template engines (ERB, Static, Liquid, JSONPath, LLM) to map data from one task's output into the format expected by the next task's input. Supports named transform definitions (Settings-based), `engine_options:` passthrough, single-hash output (1:1 dispatch), array output (fan-out/multiply), schema validation, and sequential transform chains. Requires `legion-data` (`data_required? true`).

**GitHub**: https://github.com/LegionIO/lex-transformer
**License**: MIT
**Version**: 0.3.0

## Architecture

```
Legion::Extensions::Transformer
├── Actors/
│   └── Transform          # Subscription actor consuming transform requests
├── Engines/
│   ├── Base               # Abstract engine interface
│   ├── Registry           # Maps engine name symbols to engine classes
│   ├── Erb                # ERB rendering via tilt
│   ├── Static             # JSON passthrough (no templating)
│   ├── Liquid             # Liquid template rendering
│   ├── Jsonpath           # Dot-notation value extraction from payload
│   └── Llm                # Natural language transformation via Legion::LLM
├── Helpers/
│   └── SchemaValidator    # Validates transform output against required_keys/types schema
├── Runners/
│   └── Transform          # Executes template-based payload transformation
│       ├── transform             # Entry point: render + dispatch or validate; accepts engine_options:
│       ├── transform_chain       # Sequential pipeline: N steps, output feeds next; per-step engine_options
│       ├── render_transformation # Engine dispatch (ERB/Static/Liquid/JSONPath/LLM) with engine_options
│       ├── build_template_variables # Inject crypt/settings/cache/task into scope
│       ├── dispatch_transformed  # Route Hash (single) or Array (fan-out) results
│       ├── dispatch_multiplied   # Fan-out: create a new task per array element
│       └── send_task             # Publish transformed payload to next runner
├── Definitions            # Named transform definitions loaded from Settings (lex-transformer.definitions.*)
├── Transport/
│   ├── Exchanges/Task     # Publishes to the task exchange
│   ├── Queues/Transform   # Subscribes to transformation queue
│   └── Messages/Message   # Transform request message format
└── Client                 # Standalone client: transform + transform_chain + transform_by_name
```

## Key Files

| Path | Purpose |
|------|---------|
| `lib/legion/extensions/transformer.rb` | Entry point (`data_required? true`) |
| `lib/legion/extensions/transformer/runners/transform.rb` | Core transformation logic |
| `lib/legion/extensions/transformer/actors/transform.rb` | AMQP subscription actor |
| `lib/legion/extensions/transformer/client.rb` | Standalone client (transform, transform_chain, transform_by_name) |
| `lib/legion/extensions/transformer/definitions.rb` | Named definition loader from Settings (fetch, names, merge_options) |
| `lib/legion/extensions/transformer/engines/registry.rb` | Engine name -> class lookup + auto-detection |
| `lib/legion/extensions/transformer/helpers/schema_validator.rb` | Output schema validation |
| `lib/legion/extensions/transformer/transport.rb` | Transport setup |

## Template Engines

| Engine | Name | Detection | Description |
|--------|------|-----------|-------------|
| ERB | `:erb` | `<%` or `%>` in template | Full ERB template rendering via `tilt` |
| Static | `:static` | Default (no ERB markers) | Plain JSON passthrough |
| Liquid | `:liquid` | Explicit only | Liquid template rendering (`{{ var }}`) |
| JSONPath | `:jsonpath` | Explicit only | Dot-notation value extraction from payload |
| LLM | `:llm` | Explicit only | Natural language transformation via `Legion::LLM` |

Auto-detection: ERB when template contains `<%` or `%>`, otherwise Static. Pass `engine:` to force a specific engine.

The LLM engine requires `legion-llm` to be started; it is provider-agnostic (Ollama, Bedrock, Anthropic, OpenAI, Gemini).

## Template Variables Available in ERB

| Variable | Available when |
|----------|---------------|
| All payload keys | Always (splatted into template scope) |
| `crypt` | Template string contains `'crypt'` |
| `settings` | Template string contains `'settings'` |
| `cache` | Template string contains `'cache'` |
| `task` | Template string contains `'task'` and payload has `task_id` |

## Named Transform Definitions

`Definitions` loads named transform configurations from `Legion::Settings[:lex_transformer][:definitions]`. Each definition is a hash with `:transformation`, optional `:engine`, `:schema`, `:engine_options`, and `:conditions` keys.

**`Definitions.fetch(name)`** — returns the named definition hash (symbolized) or `nil`.
**`Definitions.names`** — returns array of defined names.
**`Definitions.merge_options(definition, **overrides)`** — merges caller engine_options over definition defaults.

Client usage:

```ruby
# Define in settings: lex-transformer.definitions.my_template: { transformation: "...", engine: "erb" }
result = client.transform(name: 'my_template', payload: { foo: 'bar' })
```

If a definition includes `conditions:` (a lex-conditioner condition hash), the conditioner client is called first — the transform is skipped if conditions fail.

## Schema Validation

```ruby
schema = {
  required_keys: [:name, :email],
  types: { name: String, email: String, age: Integer }
}
```

On failure: `{ success: false, status: 'transformer.validation_failed', errors: [...] }` — no dispatch.

## Dispatch Behavior

- **Hash result**: Updates task to `transformer.succeeded`, dispatches single task, updates to `task.queued`
- **Array result**: Fan-out via `dispatch_multiplied` — creates a new task record per element, dispatches each, marks original as `task.multiplied`
- **Schema failure**: `transformer.validation_failed`, no dispatch

## Transform Chains

`transform_chain(steps:, **payload)` runs steps sequentially. Each step specifies `:transformation`, optional `:engine`, and optional `:schema`. Output of step N is merged into the running payload for step N+1. Stops on first schema failure.

## Standalone Client

`Legion::Extensions::Transformer::Client` includes the Transform runner:

```ruby
require 'legion/extensions/transformer/client'
client = Legion::Extensions::Transformer::Client.new
result = client.transform(transformation: '{"x":"<%= y %>"}', payload: { y: 'hello' })
result[:success] # => true
result[:result]  # => { x: "hello" }
```

## Dependencies

| Gem | Purpose |
|-----|---------|
| `tilt` (>= 2.3) | Template engine abstraction for ERB rendering |
| `legion-data` | Required — task record creation for fan-out |

## Testing

```bash
bundle install
bundle exec rspec     # 121 examples, 0 failures
bundle exec rubocop   # 0 offenses
```

Spec files include: `tranformer_spec.rb` (note: typo in filename), `transform_runner_spec.rb`, `definitions_spec.rb`, `client_spec.rb`, per-engine specs, `transform_chain_spec.rb`, `transform_schema_spec.rb`, and `llm_integration_spec.rb`.

---

**Maintained By**: Matthew Iverson (@Esity)
