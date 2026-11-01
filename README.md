# lex-transformer

Payload transformation for [LegionIO](https://github.com/LegionIO/LegionIO). The standalone client renders and validates data; the subscription stage uses the same client and forwards only the final output. Hash output dispatches one target; an Array of Hashes fans out into child tasks. Invalid JSON, scalar output, failed conditions, and invalid schemas never dispatch.

## Installation

```ruby
gem 'lex-transformer', '~> 0.4'
```

Ruby 3.4+ is required. This release uses `legion-settings >= 1.4.5`, `legion-data >= 1.11.0` (migrations through 144), `legion-transport >= 1.4.32`, and `lex-conditioner >= 0.4.0`. Deploy the foundation releases before this extension. Standalone rendering does not start or require a database, broker, or LegionIO runtime. Actor mode requires LegionIO >= 1.9.53 for explicit trusted-internal stage admission; durable handoffs additionally require connected, migrated Legion Data and the Tasker outbox relay.

## Standalone client

```ruby
require 'legion/extensions/transformer/client'

client = Legion::Extensions::Transformer::Client.new
result = client.transform(
  transformation: '{"greeting":"hello"}',
  payload: { name: 'world' },
  schema: { required_keys: ['greeting'], types: { greeting: 'string' } }
)
result[:success]             # true
result[:result]              # { greeting: 'hello' }
result[:definition_version]  # SHA-256 revision of the executed transform
```

`transform(payload:, transformation: nil, engine: nil, schema: nil, engine_options: {}, name: nil, steps: nil)` returns a Hash. Failures have `success: false`, a configured status, and an error/message or schema errors. Configuration and engine errors are logged. A definition with failed conditions returns the configured skipped status and the real Conditioner explanation. There is no condition bypass if Conditioner is missing or malformed.

### Chains

```ruby
result = client.transform_chain(
  payload: {},
  steps: [
    { transformation: '{"user":{"name":"Alice"}}' },
    { transformation: 'user', engine: :jsonpath }
  ]
)
result[:result] # { name: 'Alice' }
```

Each step sees previous Hash output merged into the accumulated context and the immediate output under `args`. Array output is available under `args` without replacing that context. A failed step stops the chain. The result is the **final output**, not the intermediate context. The runner accepts chains through `transform(steps: ...)`, using the same client orchestration; actor dispatch happens once, after the final step. A final Array produces one bounded fanout, not one dispatch per step.

## Settings and named definitions

Configuration lives at `extensions.transformer`. Framework runners and actors use their automatically injected `settings` helper; the standalone client, engines, definitions and transport objects read `Legion::Settings[:extensions][:transformer]` directly. Defaults register at startup, not during reads. User configuration and request overlays remain live without a loader cache or custom namespace override:

```json
{
  "extensions": {
    "transformer": {
      "allowed_engines": {"static": true, "liquid": true, "jsonpath": true, "erb": false, "llm": false},
      "default_engine": "static",
      "allow_trusted_engines": false,
      "definitions": {
        "notify": {
          "transformation": "{\"accepted\":true}",
          "engine": "static",
          "conditions": {"all": [{"fact": "allowed", "operator": "equal", "value": true}]},
          "schema": {"required_keys": ["accepted"], "types": {"accepted": "boolean"}}
        }
      }
    }
  }
}
```

```ruby
client.transform(name: 'notify', payload: { allowed: true })
```

Definitions may contain `transformation`, `engine`, `engine_options`, `schema`, `conditions`, or `steps`. Per-call engine options override definition options. An explicit transformation takes precedence over a name. String and symbol configuration keys are accepted at the schema and definition boundaries. The old `lex-transformer.definitions` namespace is no longer read.

| Setting | Default | Purpose |
|---|---|---|
| `definitions` | `{}` | Named transformation configuration |
| `allowed_engines` | `{static: true, erb: true, liquid: true, jsonpath: true, llm: true}` | Boolean grants; explicit `false` disables an inherited engine |
| `default_engine` | `static` | Non-template auto-detection |
| `template_engine` | `erb` | Auto-detection when a template marker appears |
| `template_markers` | `<%`, `%>` | Marker strings |
| `trusted_engines` | `erb` | Engines requiring explicit trusted-code opt-in |
| `allow_trusted_engines` | `false` | Administrator-controlled trusted-code opt-in |
| `queue` | `task.transform` | Subscription queue |
| `llm.max_retries` | `1` | Retries after transient errors/invalid JSON |
| `llm.retry_delay_seconds` | `1` | Delay between LLM retries |
| `llm.caller` | `{extension: 'lex-transformer', mode: 'transform'}` | Default LLM attribution |
| `execution.max_fanout` | `1000` | Local admission limit on output and child count |
| `execution.max_depth` | `100` | Local admission limit on task/child depth |

Depth and fanout limits are dynamic local policy under `extensions.transformer.execution`. Task statuses, message types, metadata fields and routes are immutable wire identities owned by `Legion::Transport::TaskProtocol`; the transform route is always `task.subtask.transform`. Strict publication policy belongs to `transport.task_publication`. Settings are process-local, not distributed state: changing local policy cannot rename persisted statuses or reinterpret a recorded transformation on replay.

Engine grants must be Boolean values, not strings or additive arrays. Set unwanted engine keys to `false`; omission retains their inherited setting. Use symbol keys in Ruby overlays (Legion JSON configuration is already symbolized). Duplicate string/symbol spellings are rejected rather than allowing an inherited grant to shadow a denial. Restrictive request overlays therefore work without changing Legion Settings' established additive-array semantics.

## Engines and trust boundary

| Engine | Behavior |
|---|---|
| `static` | JSON text or a Ruby Hash/Array passed through to validation |
| `erb` | Ruby execution through Tilt; **trusted administrator-owned templates only** |
| `liquid` | Liquid template rendering; install `liquid` to enable |
| `jsonpath` | Dot-path extraction, including numeric array indexes; final output must still be a Hash/Array of Hashes |
| `llm` | `Legion::LLM.chat` or structured output; requires a started `legion-llm` |

Engine methods return data or raise an exception; payload fields such as `success: false` remain ordinary business data. Only the outer client result's `success` field controls transformation outcome.

ERB is **not sandboxed**. An allowlist is a configuration boundary, not a Ruby security sandbox. Do not let untrusted input select, supply, or modify ERB templates, definition settings, or trusted-engine policy. When explicitly enabled, ERB can execute arbitrary code and access process resources. Tilt-compatible, non-keyword input names are available as locals. The reserved `payload` local exposes the complete original input Hash, including transport headers and keys that cannot be Ruby variables, for example `payload[:"x-legion-version"]`. Referenced `settings`, `crypt`, and `cache` modules are exposed when loaded, and `task` is a plain task-values Hash when a task exists. Use Static, Liquid, or JSONPath for untrusted data transformations.

LLM engine options include `model`, `provider`, `temperature`, `system_prompt`, `caller`, `structured`, `schema`, `max_retries`, and `retry_delay_seconds`. Only transient network/timeout and invalid-JSON errors retry. Permanent provider errors are logged and surfaced. JSON parsing uses Legion JSON throughout; output validation applies equally to every engine.

## Schema boundary

This is a field/type validator, **not a complete JSON Schema implementation**. Supported forms are `required_keys`/`types` and the equivalent JSON-style `required`/`properties.<field>.type`. Every object in a fanout is checked. A missing required field or wrong type returns `transformer.validation_failed`.

Supported type names are `string`, `integer`, `number`, `float`, `boolean`, `object`/`hash`, `array`, and `null`/`nilclass`; Ruby classes such as `String`, `Integer`, `Hash`, and `Numeric` also work. Names are case-insensitive. Unsupported types fail clearly rather than silently disabling checks.

## Runtime handoff and replay

The actor is an orchestration stage (`use_runner? false`): it does not claim or complete the eventual target runner. It accepts the same transform/chain arguments plus canonical task metadata. Business data belongs in `args`; transformed values cannot overwrite routing, policy identity, or lineage.

- A persisted single-output task retains its original `task_id`, parent/master lineage, policy context, schema, engine options, schedule/occurrence, correlation and definition revision.
- The stage records its validated result and revision in `tasks.transformation_result`, then records the target dispatch transactionally. A replay reuses that record even if the template or local admission policy subsequently changes. Data owns each task's persisted execution-policy snapshot (migration 144), leases and retry timing; Transformer does not override that authority.
- Fanout creates children with `parent_id` pointing to the logical transform task and preserved master lineage. Atomic `create_task` plus dispatch insertion uses deterministic parent/revision/index identities. Replays do not multiply children. The parent becomes `task.multiplied`, which denotes fanout handoff, **not completion of the child effects**.
- All durable publication is performed by the Tasker outbox relay. Recording an intent is not a claim of delivery or task completion. Failed publication remains recoverable.
- Cancelled, expired, terminal, or already-running tasks are not dispatched again. Child depth and fanout bounds are checked before child creation.
- Without connected Data/task storage, publication uses `publish!` and raises on rejection; the response says `durable: false`. Ephemeral mode does not promise replay deduplication or durable fanout. An explicit `function` and full `runner_routing_key` are required when no database-backed `function_id` can be resolved. The latter is the canonical `<extension>.<runner>.<function>` target route and is forwarded unchanged.

Attempt IDs and execution tokens are not inherited by new target dispatches: target execution must obtain its own claim. Durable identity prevents duplicated child creation, not exactly-once external effects at an arbitrary service.

## Development

Guarded companion Gemfile paths use `.ci-dependencies/<repo>` when that directory exists, otherwise sibling worktrees. They do not change installed-gem behavior or use Git URLs. Release gates:

```bash
bundle exec rubocop -A
bundle exec rspec --format json --out tmp/rspec_results.json --format progress --out tmp/rspec_progress.txt
```

The regression suite uses real Legion JSON, Settings, Logging, Conditioner, SQLite task persistence, and local transport. No broker or LLM credentials are required.

## License

MIT
