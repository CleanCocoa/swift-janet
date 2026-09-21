#!/bin/bash
# Runs the package's test bundle under macOS `leaks` to check that releasing
# JanetRuntime instances frees the Janet VM and its executor thread.
# Usage: Scripts/leaks.sh [--filter <test-or-suite-name>] [--graph <path.memgraph>]
# --graph writes a memory graph for Xcode's Memory Graph Debugger (File > Open)
# instead of the text report; `leaks <path.memgraph>` prints the report from it.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"

leaks_args=()
test_args=()
while [ $# -gt 0 ]; do
  case "$1" in
    --filter) test_args+=(--filter "${2:?--filter needs a test name}"); shift 2 ;;
    --graph) leaks_args+=("--outputGraph=${2:?--graph needs a path}"); shift 2 ;;
    *) echo "usage: $0 [--filter <test-or-suite-name>] [--graph <path.memgraph>]" >&2; exit 2 ;;
  esac
done

cd "$root"
swift build --build-tests
bin="$(swift build --show-bin-path)"
bundle="$bin/JanetPackageTests.xctest/Contents/MacOS/JanetPackageTests"
developer="$(xcode-select -p)"
helper="$developer/Toolchains/XcodeDefault.xctoolchain/usr/libexec/swift/pm/swiftpm-testing-helper"

# `leaks` is SIP-restricted, so DYLD_FRAMEWORK_PATH set here never reaches the
# helper; the bundle's @rpath points at the bin dir, so link Testing.framework there.
ln -sfn "$developer/Platforms/MacOSX.platform/Developer/Library/Frameworks/Testing.framework" "$bin/Testing.framework"

log="$(mktemp)"
trap 'rm -f "$log"' EXIT
leaks "${leaks_args[@]+"${leaks_args[@]}"}" -atExit -- \
  "$helper" --test-bundle-path "$bundle" --testing-library swift-testing "${test_args[@]+"${test_args[@]}"}" \
  2>&1 | tee "$log"
grep -qE 'leaks for|Output graph successfully written' "$log" \
  || { echo "leaks produced no report; the test process probably crashed before exit" >&2; exit 1; }
