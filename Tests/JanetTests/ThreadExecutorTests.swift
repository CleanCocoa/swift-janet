import Foundation
import Testing
@testable import Janet

actor PinnedActor {
    private let executor = ThreadExecutor(name: "PinnedActorTests")
    nonisolated var unownedExecutor: UnownedSerialExecutor { executor.asUnownedSerialExecutor() }

    func currentThreadID() -> ObjectIdentifier { ObjectIdentifier(Thread.current) }
    func currentThreadName() -> String? { Thread.current.name }
    func isOnExecutorThread() -> Bool { executor.isCurrentThread }
}

struct ThreadExecutorTests {
    @Test func runsEveryJobOnTheSameDedicatedThread() async {
        let pinned = PinnedActor()
        var threads: Set<ObjectIdentifier> = []
        for _ in 0..<20 {
            threads.insert(await pinned.currentThreadID())
            await Task.yield()
        }
        #expect(threads.count == 1)
        #expect(threads.first != ObjectIdentifier(Thread.main))
        #expect(await pinned.currentThreadName() == "PinnedActorTests")
        #expect(await pinned.isOnExecutorThread())
    }

    @Test func distinctExecutorsUseDistinctThreads() async {
        let a = PinnedActor()
        let b = PinnedActor()
        #expect(await a.currentThreadID() != b.currentThreadID())
    }
}
