# swift-janet

[Janet](https://janet-lang.org) embedded in Swift via SwiftPM.

Two library products:

- `CJanet`: the vendored Janet amalgamation (`janet.c` + `janet.h`), importable as a
  C module. Use this when you want the raw C API.
- `Janet`: a Swift layer on top. `JanetRuntime` owns one VM, `JanetValue` is a
  Swift-owned copy of a Janet value, `JanetError` carries parse/compile/runtime failures.

## Usage

```swift
import Janet

let janet = JanetRuntime()
janet.define("greeting", .string("hello"))
let result = try janet.eval("(string greeting \", world\")")
// result == .string("hello, world")
```

`JanetValue` models nil, booleans, numbers, strings, keywords, symbols, tuples,
arrays, structs and tables. Anything else (functions, fibers, buffers, abstracts)
arrives as `.unsupported(typeName:)`.

## Caveats

- The Janet VM is thread-local. Use a `JanetRuntime` only on the thread that created
  it, and keep at most one per thread. The type is deliberately not `Sendable`.
- Janet prints error diagnostics to stderr before `eval` throws.
- Values are deep-copied across the boundary in both directions.

## Updating Janet

```sh
Scripts/vendor-janet.sh v1.42.1
```

This clones the tag, builds the amalgamation with Janet's own Makefile, and copies
`janet.c`, `janet.h`, `LICENSE` and a `VERSION` marker into `Sources/CJanet`.
Janet is MIT licensed; see `Sources/CJanet/LICENSE`.
