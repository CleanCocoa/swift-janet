# Benchmark

Measures how much the Swift layers add on top of the raw Janet C API.

```sh
Benchmark/run.sh            # 20 000 iterations per row
Benchmark/run.sh 100000     # more iterations, steadier numbers
```

## Method

`Sources/LayersBenchmark.swift` evaluates the same script through each layer a caller
passes on the way to `janet_dostring`, so the difference between two rows is the cost
of exactly one layer:

| Row | What runs | Adds |
|---|---|---|
| `raw janet_dostring` | the C API on a `JanetVM`'s environment | nothing |
| `JanetVM.eval` | same, plus error mapping and the deep copy into `JanetValue` | the copy layer, including the depth and cycle guard |
| `JanetRuntime.eval` | same, through the actor | the hop to the executor thread and back |

The first two rows run on one detached thread so no hop is included. The third row
awaits the actor from a cooperative-pool thread, which is how callers use it.

Each row is wall-clock time for `iterations` sequential calls divided by the count,
measured with `ContinuousClock`. There is no warm-up and no statistics; run it a few
times and read the trend, not the last digit.

## How it is wired

The benchmark is a test target, `JanetBenchmarks`, whose sources live in this folder so
it can `@testable import Janet` and reach the internal `JanetVM`. The suite is gated on
the `JANET_BENCHMARK` environment variable, so `swift test` reports it as skipped and it
only runs through `run.sh`, which sets the variable, builds in release, and passes
`-enable-testing` so the release build keeps internal symbols reachable.

Debug numbers are not meaningful for Swift code; always use release.

## Reference numbers

Apple Silicon, macOS 26, Swift 6.3.3, release, 20 000 iterations, 2026-09-21:

```
scalar       raw janet_dostring       1.20 µs/op
scalar       JanetVM.eval             1.18 µs/op
scalar       JanetRuntime.eval        8.38 µs/op
collection   raw janet_dostring       3.29 µs/op
collection   JanetVM.eval             4.11 µs/op
collection   JanetRuntime.eval       12.09 µs/op
nested-64    raw janet_dostring       6.34 µs/op
nested-64    JanetVM.eval            11.56 µs/op
nested-64    JanetRuntime.eval       20.69 µs/op
```

Reading: the copy layer is free for scalars, under a microsecond for a 30-leaf
collection, and about 80 ns per nesting level. The actor hop costs 6 to 9 µs per call,
which is two context switches through the executor's condition variable. For trivial
scripts the hop dominates; amortize it by doing more work per call rather than by
tuning the executor.
