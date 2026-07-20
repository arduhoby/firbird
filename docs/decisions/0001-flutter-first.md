# ADR 0001: Flutter-first mobile application

## Status

Accepted

## Decision

FirBird will use Flutter and Dart for the mobile UI and application workflow. Performance-sensitive inference remains behind a platform-independent interface and may use isolates, FFI, or a focused native adapter when benchmarks justify it.

## Consequences

Android ships first, while the UI and package workflow remain portable to iOS.
