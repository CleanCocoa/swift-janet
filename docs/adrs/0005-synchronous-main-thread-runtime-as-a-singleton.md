# ADR-0005: Synchronous main-thread runtime as a singleton

**Date:** 2026-09-21
**Status:** Accepted
**Area:** Public API

## Context

An editor that answers each keypress with a script wants to call `eval` without
`await`, and without other main-actor work interleaving between the call and its
result. Three shapes were weighed: (A) a separate `@MainActor` type with a synchronous
API; (B) letting `JanetRuntime` take an executor, such as the main actor's; (C) making
`JanetVM` public and letting apps host it. With B the compiler still forces `await` at
every call site, because it cannot see that caller and actor share an executor, and
reentrancy stays possible. C exposes the thread-affinity rules to every app.

A second question was whether apps may create several main-thread VMs. Two view
controllers each making their own would hit the trap from ADR-0003 on the second one.

## Decision

Shape A. `MainJanetRuntime` is a `@MainActor final class` with synchronous `eval`,
`define` and `reset`. Its initializer is not public; the only instance is
`JanetRuntime.main`, so the main thread's VM cannot be duplicated by construction.
`reset()` restarts the VM in place and traps if called during an evaluation, since a
cfunction calling back into Swift could otherwise pull the VM out from under the
interpreter.

## Consequences

- No hop: `eval` on the main runtime costs about the same as the raw C call, versus
  5 to 7 µs through the actor.
- Every call blocks the main thread for its duration. Long scripts belong on a
  `JanetRuntime`.
- The VM lives for the process, so state is cleared with `reset()`, not by dropping the
  object. Tests that share it must serialize.
- Apps cannot construct the concrete type for test doubles; they wrap it in their own
  protocol if they need one. This is the `UserDefaults.standard` trade.
