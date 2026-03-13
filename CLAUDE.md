# lex-transformer: Payload Transformation Engine for LegionIO

**Repository Level 3 Documentation**
- **Category**: `/Users/miverso2/rubymine/legion/CLAUDE.md`

## Purpose

Legion Extension that transforms task payloads between services in a relationship chain. Uses template-based transformation (via the `tilt` gem) to map data from one task's output into the format expected by the next task's input.

**License**: MIT

## Architecture

```
Legion::Extensions::Transformer
├── Actors/
│   └── Transform          # Subscription actor consuming transform requests
├── Runners/
│   └── Transform          # Executes template-based payload transformation
└── Transport/
    ├── Exchanges/Task     # Publishes to the task exchange
    ├── Queues/Transform   # Subscribes to transformation queue
    └── Messages/Message   # Transform request message format
```

## Key Files

| Path | Purpose |
|------|---------|
| `lib/legion/extensions/transformer.rb` | Entry point, extension registration |
| `lib/legion/extensions/transformer/runners/transform.rb` | Core transformation logic |
| `lib/legion/extensions/transformer/actors/transform.rb` | AMQP subscription actor |
| `lib/legion/extensions/transformer/transport.rb` | Transport setup |

## Dependencies

| Gem | Purpose |
|-----|---------|
| `tilt` | Template engine abstraction (ERB, etc.) |

## Testing

```bash
bundle install
bundle exec rspec
bundle exec rubocop
```

---

**Maintained By**: Matthew Iverson (@Esity)
