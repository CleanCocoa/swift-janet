# ADR-0003: Trap on VM misuse

**Date:** 2026-09-21
**Status:** Accepted
**Area:** Concurrency / Safety

## Context

A second `janet_init` on a thread silently clobbers the first VM, and calling into a VM
from another thread corrupts it. Neither Swift nor Janet detects this. Options were to
document the rule only, to make every host a singleton, or to check at runtime.

## Decision

`JanetVM` records its creating thread and sets a per-thread flag. Creating a VM on a
thread that already has one, or calling `eval`, `define`, `reset` or `deinit` from another
thread, hits a `precondition` and crashes. Singletons are layered on top only where
accidental duplication is likely (the main thread, ADR-0005); the trap is the invariant.

## Consequences

- Misuse is a crash with a message, not silent corruption discovered later.
- A "check first" API is unnecessary: the only way to hit the trap is a bug.
- `JanetRuntime`'s `isolated deinit` also calls `checkIsolated()`, so dropping the
  `isolated` keyword fails the teardown test instead of compiling silently.
