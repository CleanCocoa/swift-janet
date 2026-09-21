# swift-janet

[Janet](https://janet-lang.org) embedded in Swift via SwiftPM.

Two library products:

- `CJanet`: the vendored Janet amalgamation (`janet.c` + `janet.h`), importable as a
  C module. Use this when you want the raw C API.
- `Janet`: a Swift layer on top. `JanetRuntime` is an actor that owns one VM on its
  own thread, `JanetRuntime.main` is the synchronous main-thread VM, `JanetValue` is a
  Swift-owned copy of a Janet value, `JanetError` carries parse/compile/runtime failures.

Requires macOS 26 and Swift 6.3 (strict concurrency, `isolated deinit`).

Design decisions are recorded in `docs/adrs/`; releases in `CHANGELOG.md`.

## Usage

```swift
import Janet

let janet = JanetRuntime()
try await janet.define("greeting", .string("hello"))
let result = try await janet.eval("(string greeting \", world\")")
// result == .string("hello, world")
```

On the main thread, `JanetRuntime.main` interprets synchronously, with no hop and no
chance for other main-actor work to interleave between a call and its result:

```swift
@MainActor func run() throws {
    try JanetRuntime.main.define("greeting", .string("hello"))
    let result = try JanetRuntime.main.eval("(string greeting \", world\")")
    // result == .string("hello, world")
}
```

There is one such VM per process, and every call blocks the main thread for its duration.

`JanetValue` models nil, booleans, numbers, strings, keywords, symbols, tuples,
arrays, structs and tables. Anything else (functions, fibers, buffers, abstracts)
arrives as `.unsupported(typeName:)`.

## Caveats

- The Janet VM is thread-local, so each `JanetRuntime` runs on a dedicated thread it
  owns. The runtime is `Sendable` and can be called from anywhere; create several to
  run scripts in parallel. The thread and VM are torn down when the runtime is released.
- At most one VM may be live per thread: creating a second one there, or touching a VM
  from another thread, traps. `JanetRuntime.main` owns the main thread's VM, so do not
  put another one there.
- Janet prints error diagnostics to stderr before `eval` throws.
- Values are deep-copied across the boundary in both directions. A result nested deeper
  than 256 levels, or containing a cycle through an array or table, makes `eval` throw
  with phase `.copy` instead of overflowing the stack of whichever thread releases it.

## Benchmarking

`Benchmark/run.sh` measures what the Swift layers add over the raw C API; see
`Benchmark/README.md` for the method and reference numbers.

## Updating Janet

```sh
Scripts/vendor-janet.sh v1.42.1
```

This clones the tag, builds the amalgamation with Janet's own Makefile, and copies
`janet.c`, `janet.h`, `LICENSE` and a `VERSION` marker into `Sources/CJanet`.
Janet is MIT licensed; see `Sources/CJanet/LICENSE`.

## Checking for leaks

`Scripts/leaks.sh [--filter <test-or-suite>] [--graph <path.memgraph>]` runs the test
bundle under macOS `leaks -atExit` and reports whether released `JanetRuntime` instances left the Janet VM or executor thread behind.
