# ADR-0002: Pin each runtime to a dedicated thread

**Date:** 2026-09-18
**Status:** Accepted
**Area:** Concurrency

## Context

Janet's VM (`janet_vm`) is a `__thread` global. A plain Swift actor does not promise a
thread: its jobs migrate across the cooperative pool, so isolation alone would let two
runtimes share a VM or a runtime see an empty one. `@TaskLocal` cannot help either, since
it follows the task tree, not the OS thread. A serial `DispatchQueue` does not pin a
thread. Hosting the VM on the main actor works but blocks the UI for every call.

## Decision

`JanetRuntime` is an actor whose `unownedExecutor` is a `ThreadExecutor`: one `Thread`
running a condition-variable job loop. One actor is one VM is one thread. The VM is
created lazily on that thread and released in `isolated deinit`.

The job loop uses `NSCondition`. Benchmarked alternatives (raw `pthread_cond_t`,
`Mutex` plus `DispatchSemaphore`, `os_sync_wait_on_address`) all cost the same 3 to 4 µs
per handoff, because the cost is waking a parked thread. `Mutex` plus semaphore adds a
priority-inversion risk; `os_sync_wait_on_address` needs a C shim for a gain within noise.

## Consequences

- Every call pays a thread hop, about 5 to 7 µs on top of the C cost. For UI code that
  wants synchronous calls, use `JanetRuntime.main` (ADR-0005).
- Runtimes are `Sendable` and parallel by construction; the "one VM per thread" rule is
  structural rather than documented.
- `ThreadExecutor.swift` is the only file that touches Foundation threading. Porting to
  Linux or Windows means swapping that file, not the public API.
- Job priority and QoS are not propagated; the thread inherits the QoS of whoever
  created the runtime.
