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

You can call Legion services within transformations:

```json
{"token": "<%= Legion::Crypt.read('pushover/token') %>", "message": "Hello from Vault"}
```

## Requirements

- Ruby >= 3.4
- [LegionIO](https://github.com/LegionIO/LegionIO) framework
- `tilt` gem

## License

MIT
