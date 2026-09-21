# swift-janet

[Janet](https://janet-lang.org) embedded in Swift via SwiftPM.

Two library products:

- `CJanet`: the vendored Janet amalgamation (`janet.c` + `janet.h`), importable as a
  C module. Use this when you want the raw C API.
- `Janet`: a Swift layer on top. `JanetRuntime` is an actor that owns one VM on its
  own thread, `JanetValue` is a Swift-owned copy of a Janet value, `JanetError`
  carries parse/compile/runtime failures.

Requires macOS 26 and Swift 6.3 (strict concurrency, `isolated deinit`).

## Usage

```swift
import Janet

let janet = JanetRuntime()
await janet.define("greeting", .string("hello"))
let result = try await janet.eval("(string greeting \", world\")")
// result == .string("hello, world")
```

`JanetValue` models nil, booleans, numbers, strings, keywords, symbols, tuples,
arrays, structs and tables. Anything else (functions, fibers, buffers, abstracts)
arrives as `.unsupported(typeName:)`.

## Caveats

- The Janet VM is thread-local, so each `JanetRuntime` runs on a dedicated thread it
  owns. The runtime is `Sendable` and can be called from anywhere; create several to
  run scripts in parallel. The thread and VM are torn down when the runtime is released.
- Janet prints error diagnostics to stderr before `eval` throws.
- Values are deep-copied across the boundary in both directions.

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
