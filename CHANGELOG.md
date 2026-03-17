# Changelog

## [0.2.0] - 2026-03-17

### Added
- Pluggable engine system with `Engines::Base`, `Engines::Erb`, `Engines::Static`, and `Engines::Registry`
- `Engines::Registry.detect` auto-selects ERB or static engine based on template content
- `render_transformation` now accepts optional `engine:` keyword to force a specific engine
- `transform` runner accepts optional `engine:` from payload for explicit engine selection
- 8 new specs covering engine registry, ERB rendering, and static rendering

### Fixed
- `dispatch_multiplied` payload mutation bug: `new_payload = payload` replaced with `new_payload = payload.dup`

### Changed
- ERB rendering logic extracted from runner into `Engines::Erb` class
- `build_template_variables` moved to `Engines::Erb` as private `build_variables`
- Runner no longer directly requires `tilt` (delegated to `Engines::Erb`)

## [0.1.4] - 2026-03-13

### Added
- Initial release
