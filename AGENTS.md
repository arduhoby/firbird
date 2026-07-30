# FirBird code integrity rule

Before changing application code, use the global `reuse-before-write` skill and
complete a repository-wide reuse audit.

One responsibility has exactly one canonical implementation. Every entry point
must call that implementation through a typed contract. In particular:

- Media playback has one controller, one platform-channel gateway, and one
  replay surface.
- Bird metadata has one catalog/repository.
- Bird imagery has one shared widget and one fallback policy.
- Live completion, history, and direct navigation may adapt data, but may not
  own separate playback, metadata lookup, or image-loading behavior.

Do not add a second implementation for convenience. A real platform exception
requires a shared interface, written evidence, and parity tests.

Before finishing, search for duplicate channels, controllers, widgets, parsers,
and lookup keys. Run the architecture integrity tests and report the canonical
implementation and all callers.
