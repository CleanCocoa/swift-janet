#!/bin/bash
# Runs the layer benchmark in a release build and prints µs per operation.
# Usage: Benchmark/run.sh [iterations]
set -euo pipefail
cd "$(dirname "$0")/.."
JANET_BENCHMARK=1 JANET_BENCHMARK_ITERATIONS="${1:-20000}" \
  swift test -c release -Xswiftc -enable-testing --filter LayersBenchmark 2>&1 \
  | grep -E 'µs/op|error:'
