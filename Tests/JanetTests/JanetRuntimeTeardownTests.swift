import Foundation
import Testing
@testable import Janet

struct JanetRuntimeTeardownTests {
    @Test func releasingTheRuntimeExitsItsThread() async throws {
        var runtime: JanetRuntime? = JanetRuntime(name: "teardown")
        try await runtime!.eval("(+ 1 1)")
        let exited = AsyncStream<String?>.makeStream()
        runtime!.executor.onThreadExit { exited.continuation.yield(Thread.current.name) }
        runtime = nil
        let exitedThread = await withTimeout(seconds: 5) {
            for await name in exited.stream { return name }
            return nil
        }
        #expect(exitedThread == "teardown")
    }
}

private func withTimeout<T: Sendable>(seconds: Double, _ body: @escaping @Sendable () async -> T?) async -> T? {
    await withTaskGroup(of: T?.self) { group in
        group.addTask { await body() }
        group.addTask { try? await Task.sleep(for: .seconds(seconds)); return nil }
        let first = await group.next() ?? nil
        group.cancelAll()
        return first
    }
}
