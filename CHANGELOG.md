# Changelog

Notable changes to this package. Small fixes and refactors are left out; the git log has them.

## 0.1.1 - 2026-09-21

- The executor traps if a second thread ever enters its job loop, closing the last
  path by which Janet could run on the wrong thread.
- README usage now leads with a comparison of the two runtimes.
- The raw C API smoke test moved to its own `CJanetTests` target.

## 0.1.0 - 2026-09-21

First release, intended for test-driving in apps. Requires macOS 26 and Swift 6.3 in
Swift 6 language mode. Bundles Janet 1.42.1.

### Concurrency

- `JanetRuntime` is an actor pinned to its own OS thread through a custom serial
  executor. Janet's VM state is thread-local, so pinning is what makes the actor
  safe; plain actor isolation would not be. The runtime is `Sendable` and can be
  called from anywhere with `await`. Create several to run scripts in parallel.
  See [ADR-0002](docs/adrs/0002-pin-each-runtime-to-a-dedicated-thread.md).
- The VM is created on first use and torn down on the executor thread when the
  runtime is released. Releasing the last reference frees the VM and exits the
  thread; `Scripts/leaks.sh` checks that under `leaks`.
- Misusing a VM traps instead of corrupting memory: creating a second VM on a
  thread that already has one, or touching a VM from another thread.
  See [ADR-0003](docs/adrs/0003-trap-on-vm-misuse.md).

### Main-thread runtime

- `JanetRuntime.main` is a synchronous, `@MainActor` VM for UI code: `eval` and
  `define` run on the caller's thread with no `await` and no chance for other
  main-actor work to interleave. There is one per process and every call blocks the
  main thread for its duration.
  See [ADR-0005](docs/adrs/0005-synchronous-main-thread-runtime-as-a-singleton.md).
- `JanetRuntime.main.reset()` discards every definition and restarts the VM in place.
  Calling it during an evaluation traps.

### Values and errors

- `JanetValue` is a Swift-owned deep copy of a Janet value: nil, booleans, numbers,
  strings, keywords, symbols, tuples, arrays, structs and tables. It is `Hashable`
  and `Sendable` and never references VM memory. Functions, fibers, buffers and
  abstracts arrive as `.unsupported(typeName:)`.
- `define(_:_:documentation:)` binds a `JanetValue` in the core environment so later
  evaluations can use it.
- Values nested deeper than 256 levels, or containing a cycle through an array or
  table, are rejected in both directions with a `JanetError` of phase `.copy`
  instead of overflowing a stack.
  See [ADR-0004](docs/adrs/0004-deep-copy-values-and-bound-their-depth.md).
- `JanetError` carries a `phase` (`.parse`, `.compile`, `.runtime`, `.copy`) and
  Janet's message. All entry points use typed throws.

### Platform

- Deployment floor is macOS 26 so the runtime can use `isolated deinit`.
  See [ADR-0001](docs/adrs/0001-require-macos-26.md).
- Executor threads get an 8 MB stack, matching the main thread, instead of the
  512 KB Darwin default.

### Tooling

- `CJanet` product exposes the vendored amalgamation for callers who want the raw
  C API. `Scripts/vendor-janet.sh <tag>` regenerates it.
- `Benchmark/run.sh` measures what each Swift layer adds over `janet_dostring`;
  `Benchmark/README.md` documents the method and reference numbers.
- `Scripts/leaks.sh` runs the test suite under macOS `leaks`.

### Known limitations

- Only scalars and the four collection types cross the boundary. Calling Janet
  functions from Swift, or Swift from Janet, is not modeled yet.
- The stack size and nesting limit are constants, not initializer parameters.
- macOS only for now. `ThreadExecutor.swift` is the one file to swap for other
  platforms.
