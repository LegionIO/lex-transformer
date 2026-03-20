# lex-transformer

Payload transformation engine for [LegionIO](https://github.com/LegionIO/LegionIO). Transforms task payloads between services in a relationship chain using pluggable template engines. Maps data from one task's output into the format expected by the next task's input.

## Installation

```bash
gem install lex-transformer
```

Or add to your Gemfile:

```ruby
gem 'lex-transformer'
```

## Standalone Client

Use the transformer without the full LegionIO framework:

```ruby
require 'legion/extensions/transformer/client'

client = Legion::Extensions::Transformer::Client.new

# Single transform
result = client.transform(
  transformation: '{"greeting":"hello <%= name %>"}',
  payload: { name: 'world' }
)
result[:success] # => true
result[:result]  # => { greeting: "hello world" }

# With explicit engine
result = client.transform(
  transformation: '{"greeting":"hello {{ name }}"}',
  payload: { name: 'world' },
  engine: :liquid
)

# With engine options (passed through to the engine)
result = client.transform(
  transformation: 'Summarize this in one sentence',
  payload: { text: 'Long article...' },
  engine: :llm,
  engine_options: { model: 'claude-opus-4-6', temperature: 0.3 }
)

# With schema validation
result = client.transform(
  transformation: '{"name":"test"}',
  payload: {},
  schema: { required_keys: [:name, :email] }
)
result[:success] # => false
result[:status]  # => "transformer.validation_failed"
result[:errors]  # => ["missing required key: email"]

# By named definition (loaded from Legion::Settings)
result = client.transform(name: 'my_template', payload: { foo: 'bar' })
```

### Transform Chains

Pipe data through sequential transformation steps:

```ruby
result = client.transform_chain(
  steps: [
    { transformation: '{"user":"<%= login %>"}', schema: { required_keys: [:user] } },
    { transformation: '{"message":"Welcome, <%= user %>!"}' }
  ],
  payload: { login: 'alice' }
)
result[:success]        # => true
result[:result][:args]  # => { message: "Welcome, alice!" }
```

Each step's output merges into the running payload, so subsequent steps can reference keys from earlier steps.

## Engines

| Engine | Name | Detection | Description |
|--------|------|-----------|-------------|
| ERB | `:erb` | `<%` or `%>` in template | Full ERB template rendering via `tilt` |
| Static | `:static` | Default (no ERB markers) | Plain JSON passthrough |
| Liquid | `:liquid` | Explicit only | Liquid template rendering (`{{ var }}`) |
| JSONPath | `:jsonpath` | Explicit only | Dot-notation value extraction from payload |
| LLM | `:llm` | Explicit only | Natural language transformation via Legion::LLM |

Auto-detection selects ERB when the template contains ERB markers, otherwise falls back to Static. Use the `engine:` parameter to force a specific engine.

### LLM Engine

The LLM engine uses natural language instructions as the "template":

```ruby
client.transform(
  transformation: "Summarize this webhook payload into a Slack notification with the PR title and author",
  payload: { action: "opened", pull_request: { title: "Fix auth", user: { login: "alice" } } },
  engine: :llm
)
```

Requires `legion-llm` to be started. Provider-agnostic — uses whatever LLM provider is configured (Ollama, Bedrock, Anthropic, OpenAI, Gemini).

## Schema Validation

Validate transformed output against a declared schema:

```ruby
schema = {
  required_keys: [:name, :email],                    # keys that must be present
  types: { name: String, email: String, age: Integer } # optional type checks
}
```

When validation fails, the transform returns `{ success: false, status: 'transformer.validation_failed', errors: [...] }`.

## Named Definitions

Transform definitions can be registered in settings under `lex-transformer.definitions.<name>` and referenced by name:

```json
{
  "lex-transformer": {
    "definitions": {
      "slack_notify": {
        "transformation": "{\"text\":\"<%= title %> by <%= author %>\"}",
        "engine": "erb"
      }
    }
  }
}
```

```ruby
result = client.transform(name: 'slack_notify', payload: { title: 'PR merged', author: 'alice' })
```

If a definition includes `conditions:`, the conditioner client is evaluated first and the transform is skipped on failure.

## Runners

### Transform

#### `transform(transformation:, engine: nil, schema: nil, engine_options: {}, name: nil, **payload)`

Renders the transformation template against the payload, optionally validates the result, then dispatches:

- Hash result: routes to next task (`task.queued`)
- Array result: fan-out via `dispatch_multiplied` (one task per element, marked `task.multiplied`)
- Schema failure: `transformer.validation_failed`, no dispatch

#### `transform_chain(steps:, **payload)`

Sequential pipeline. Each step has `:transformation`, optional `:engine`, optional `:schema`. Output of step N feeds into step N+1. Stops on first schema failure.

## Transport

- **Exchange**: `task` (inherits from `Legion::Transport::Exchanges::Task`)
- **Queue**: `task.transform`
- **Routing keys**: `task.subtask`, `task.subtask.transform`

## Requirements

- Ruby >= 3.4
- [LegionIO](https://github.com/LegionIO/LegionIO) framework (for AMQP actor mode)
- `tilt` >= 2.3
- Standalone Client works without the framework

## License

MIT
