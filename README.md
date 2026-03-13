# lex-transformer

Payload transformation engine for [LegionIO](https://github.com/LegionIO/LegionIO). Transforms task payloads between services in a relationship chain using ERB templates via the `tilt` gem. Maps data from one task's output into the format expected by the next task's input.

This is a core LEX required for task relationship transformations.

## Installation

```bash
gem install lex-transformer
```

## Usage

Transformations use ERB syntax to map values between services:

```json
{"message": "New incident assigned to <%= assignee %> with priority <%= severity %>", "from": "PagerDuty"}
```

You can access Legion services within transformations:

```json
{"token": "<%= crypt.read('pushover/token') %>", "message": "Hello from Vault"}
```

If the template string contains no ERB tags (`<%` / `%>`), it is parsed as plain JSON.

### Fan-out (Array Output)

If a template renders to a JSON array, the transformer fans out: one downstream task is created and dispatched per array element. The original task is marked `task.multiplied`.

### Available Template Variables

All payload keys from the triggering task are in scope. Additional variables are injected on demand:
- `crypt` - `Legion::Crypt` (when template contains `'crypt'`)
- `settings` - `Legion::Settings` (when template contains `'settings'`)
- `cache` - `Legion::Cache` (when template contains `'cache'`)
- `task` - task DB record (when template contains `'task'` and `task_id` is present)

## Requirements

- Ruby >= 3.4
- [LegionIO](https://github.com/LegionIO/LegionIO) framework
- `tilt` >= 2.3

## License

MIT
