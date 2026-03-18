# lex-transformer: Payload Transformation Engine for LegionIO

**Repository Level 3 Documentation**
- **Parent**: `/Users/miverso2/rubymine/legion/extensions-core/CLAUDE.md`
- **Grandparent**: `/Users/miverso2/rubymine/legion/CLAUDE.md`

## Purpose

Legion Extension that transforms task payloads between services in a relationship chain. Uses ERB template-based transformation (via the `tilt` gem) to map data from one task's output into the format expected by the next task's input. Supports single-hash output (1:1 dispatch) and array output (fan-out/multiply). Requires `legion-data` (`data_required? true`).

**GitHub**: https://github.com/LegionIO/lex-transformer
**License**: MIT
**Version**: 0.2.1

## Architecture

```
Legion::Extensions::Transformer
├── Actors/
│   └── Transform          # Subscription actor consuming transform requests
├── Runners/
│   └── Transform          # Executes template-based payload transformation
│       ├── transform             # Entry point: render + dispatch
│       ├── render_transformation # ERB rendering via tilt, or plain JSON if no ERB tags
│       ├── build_template_variables # Inject crypt/settings/cache/task into ERB scope
│       ├── dispatch_transformed  # Route Hash (single) or Array (fan-out) results
│       ├── dispatch_multiplied   # Fan-out: create a new task per array element
│       └── send_task             # Publish transformed payload to next runner
└── Transport/
    ├── Exchanges/Task     # Publishes to the task exchange
    ├── Queues/Transform   # Subscribes to transformation queue
    └── Messages/Message   # Transform request message format
```

## Key Files

| Path | Purpose |
|------|---------|
| `lib/legion/extensions/transformer.rb` | Entry point (`data_required? true`) |
| `lib/legion/extensions/transformer/runners/transform.rb` | Core transformation logic |
| `lib/legion/extensions/transformer/actors/transform.rb` | AMQP subscription actor |
| `lib/legion/extensions/transformer/transport.rb` | Transport setup |

## Template Variables Available in ERB

| Variable | Available when |
|----------|---------------|
| All payload keys | Always (splatted into template scope) |
| `crypt` | Template string contains `'crypt'` |
| `settings` | Template string contains `'settings'` |
| `cache` | Template string contains `'cache'` |
| `task` | Template string contains `'task'` and payload has `task_id` |

## Dispatch Behavior

- **Hash result**: Updates task to `transformer.succeeded`, dispatches single task, updates to `task.queued`
- **Array result**: Fan-out via `dispatch_multiplied` - creates a new task record per element, dispatches each, marks original as `task.multiplied`
- **Plain JSON** (no ERB tags): Parsed directly without template rendering

## Dependencies

| Gem | Purpose |
|-----|---------|
| `tilt` (>= 2.3) | Template engine abstraction for ERB rendering |
| `legion-data` | Required - task record creation for fan-out |

## Testing

```bash
bundle install
bundle exec rspec
bundle exec rubocop
```

Spec files: `spec/legion/extensions/tranformer_spec.rb` (note: typo in filename), `spec/legion/extensions/transform_runner_spec.rb`

---

**Maintained By**: Matthew Iverson (@Esity)
