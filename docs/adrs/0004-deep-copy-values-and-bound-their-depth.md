# ADR-0004: Deep-copy values and bound their depth

**Date:** 2026-09-21
**Status:** Accepted
**Area:** Value boundary

## Context

Values could cross the boundary as borrowed views into VM memory or as Swift-owned
copies. Views would be `~Escapable` types, which are still behind an experimental flag,
and would tie every value to the VM's GC and thread. Copying is recursive, and a value a
few hundred levels deep overflowed the 512 KB default stack of the executor thread. The
last release of a `JanetValue` runs on whichever thread drops it, usually a 512 KB
cooperative-pool thread, so a large executor stack alone does not protect the release.
Cyclic arrays and tables recursed forever.

## Decision

`JanetValue` is a deep copy in both directions. Copying tracks depth and the set of
mutable containers on the current path; a value deeper than 256 levels or containing a
cycle makes `eval` or `define` throw a `JanetError` with phase `.copy` rather than
returning a truncated value. Executor threads get an 8 MB stack, matching the main
thread the VM ran on before.

256 is half the smallest depth measured to overflow a 512 KB thread. For comparison,
Emacs Lisp's `max-lisp-eval-depth` is 1600 on an 8 MB main thread.

## Consequences

- `JanetValue` is `Sendable` and independent of the VM's lifetime and GC, which the
  actor design depends on.
- Every crossing costs a copy; for a 30-leaf struct the benchmark puts it at about a
  quarter of the raw C eval time.
- Failures are loud: a too-deep value throws instead of comparing unequal for no
  visible reason.
- Both constants are package-internal with a TODO to expose them through
  `JanetRuntime.init` if a caller needs it. Borrowed views can be revisited once
  `~Escapable` is stable.
