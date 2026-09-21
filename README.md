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

## Installation

Add the package to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/CleanCocoa/swift-janet", from: "0.1.0"),
],
targets: [
    .target(name: "MyApp", dependencies: [.product(name: "Janet", package: "swift-janet")]),
]
```

Or in Xcode, File > Add Package Dependencies and paste the repository URL.

## Usage

The `Janet` module offers two runtimes. Pick by where the call happens:

| | `JanetRuntime` | `JanetRuntime.main` |
|---|---|---|
| Runs on | its own dedicated thread | the main thread |
| Call style | `try await` from anywhere | `try` from `@MainActor` code |
| Instances | as many as you like, each an isolated VM | exactly one per process |
| Good for | background scripts, parallel evaluation | UI that scripts each keypress |
| Cost | a thread hop per call, about 5 to 7 µs | none, but the main thread blocks |

Both share the same API: `eval` runs source and returns the last value, `define` binds
a Swift value under a name for later evaluations.

### Background: `JanetRuntime`

```swift
import Janet

let janet = JanetRuntime()
try await janet.define("greeting", .string("hello"))
let result = try await janet.eval("(string greeting \", world\")")
// result == .string("hello, world")
```

Each instance owns one VM on one thread and is `Sendable`. Drop the last reference to
tear both down.

### Main thread: `JanetRuntime.main`

```swift
@MainActor func run() throws {
    try JanetRuntime.main.define("greeting", .string("hello"))
    let result = try JanetRuntime.main.eval("(string greeting \", world\")")
    // result == .string("hello, world")
}
```

Calls are synchronous, so nothing else on the main actor can interleave between a call
and its result. State lives for the process; `JanetRuntime.main.reset()` discards every
definition.

### Values and errors

`JanetValue` is a Swift-owned copy of a Janet value: nil, booleans, numbers, strings,
keywords, symbols, tuples, arrays, structs and tables. Anything else (functions, fibers,
buffers, abstracts) arrives as `.unsupported(typeName:)`.

`JanetError` carries Janet's message and the `phase` that failed: `.parse`, `.compile`,
`.runtime`, or `.copy` when a value could not cross the boundary.

## Caveats

- At most one VM may be live per thread: creating a second one there, or touching a VM
  from another thread, traps. `JanetRuntime.main` owns the main thread's VM, so do not
  put another one there.
- Janet prints error diagnostics to stderr before `eval` throws.
- Values are deep-copied across the boundary in both directions. A result nested deeper
  than 256 levels, or containing a cycle through an array or table, makes `eval` throw
  with phase `.copy` instead of overflowing the stack of whichever thread releases it.

## Learning Janet

- [Learn Janet in Y minutes](https://learnxinyminutes.com/janet) for a one-page tour of the syntax.
- [Janet for Mortals](https://janet.guide/) for a book-length introduction.
- [The Janet reference](https://janet-lang.org/docs/index.html) for the language and core library.

## Benchmarking

`Benchmark/run.sh` measures what the Swift layers add over the raw C API; see
`Benchmark/README.md` for the method and reference numbers.

## Updating Janet

```sh
Scripts/vendor-janet.sh v1.42.1
```

This clones the tag, builds the amalgamation with Janet's own Makefile, and copies
`janet.c`, `janet.h`, `LICENSE` and a `VERSION` marker into `Sources/CJanet`.

## Checking for leaks

`Scripts/leaks.sh [--filter <test-or-suite>] [--graph <path.memgraph>]` runs the test
bundle under macOS `leaks -atExit` and reports whether released `JanetRuntime` instances left the Janet VM or executor thread behind.

## License

MIT; see `LICENSE`. The vendored Janet sources are also MIT licensed; see
`Sources/CJanet/LICENSE`.
