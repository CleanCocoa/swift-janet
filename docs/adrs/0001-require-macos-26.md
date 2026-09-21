# ADR-0001: Require macOS 26

**Date:** 2026-09-18
**Status:** Accepted
**Area:** Package manifest

## Context

`JanetRuntime` must run `janet_deinit` on the thread that ran `janet_init`. The clean
way for an actor to do that is `isolated deinit`, which needs macOS 15.4. `Span`,
`UTF8Span` and `String(copying:)`, which a future zero-copy boundary would use, need
macOS 26. The alternative to `isolated deinit` is a nonisolated `deinit` that enqueues a
teardown job and joins the thread.

## Decision

Set `platforms: [.macOS(.v26)]` and use `isolated deinit`.

## Consequences

- Teardown is a one-liner the compiler enforces, and a precondition catches anyone who
  drops the keyword.
- `Span`-based fast paths are available without `#available` gates.
- Apps on older macOS cannot adopt the package. Lowering the floor to 15.4 later only
  costs the `Span` option, not the design.
