import CJanet
import Foundation
@testable import Janet
import Testing

/// Times the same script at each layer between a caller and the C API, so the
/// difference between rows is the cost of one layer.
@Suite(.enabled(if: ProcessInfo.processInfo.environment["JANET_BENCHMARK"] != nil))
struct LayersBenchmark {
    static let iterations = Int(ProcessInfo.processInfo.environment["JANET_BENCHMARK_ITERATIONS"] ?? "") ?? 20_000

    static let scripts = [
        ("scalar", "(+ 1 2)"),
        ("collection", "{:a [1 2 3] :b @{:x \"y\"} :c (range 20)}"),
        ("nested-64", "(reduce (fn [acc _] [acc]) 1 (range 64))"),
    ]

    @Test func layers() async throws {
        let runtime = JanetRuntime()
        for (label, script) in Self.scripts {
            let (raw, copied) = await Task.detached { Self.timeOnOneThread(script) }.value
            report(label, "raw janet_dostring", raw)
            report(label, "JanetVM.eval", copied)
            report(label, "JanetRuntime.eval", try await timeAsync { _ = try await runtime.eval(script) })
        }
    }

    /// Layers below the actor, measured on a single thread so no hop is included.
    @Sendable private static func timeOnOneThread(_ script: String) -> (raw: Double, copied: Double) {
        let vm = JanetVM()
        var out = janet_wrap_nil()
        let raw = timeSync { _ = janet_dostring(vm.env, script, "benchmark", &out) }
        let copied = try! timeSync { _ = try vm.eval(script) }
        return (raw, copied)
    }
}

private func report(_ script: String, _ layer: String, _ nanosPerOp: Double) {
    let micros = String(format: "%8.2f", nanosPerOp / 1000)
    let line = "\(script.padding(toLength: 12, withPad: " ", startingAt: 0)) \(layer.padding(toLength: 20, withPad: " ", startingAt: 0)) \(micros) µs/op\n"
    FileHandle.standardError.write(line.data(using: .utf8)!)
}

private func timeSync(_ body: () throws -> Void) rethrows -> Double {
    let clock = ContinuousClock()
    let start = clock.now
    for _ in 0..<LayersBenchmark.iterations { try body() }
    return nanoseconds(clock.now - start) / Double(LayersBenchmark.iterations)
}

private func timeAsync(_ body: () async throws -> Void) async rethrows -> Double {
    let clock = ContinuousClock()
    let start = clock.now
    for _ in 0..<LayersBenchmark.iterations { try await body() }
    return nanoseconds(clock.now - start) / Double(LayersBenchmark.iterations)
}

private func nanoseconds(_ duration: Duration) -> Double {
    (Double(duration.components.seconds) * 1e18 + Double(duration.components.attoseconds)) / 1e9
}
