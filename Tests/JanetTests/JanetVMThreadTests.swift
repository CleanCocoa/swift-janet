import Foundation
@testable import Janet
import Testing

struct JanetVMThreadTests {
    @Test func trapsOnSecondVMForSameThread() async {
        await #expect(processExitsWith: .failure) {
            let first = JanetVM()
            withExtendedLifetime(first) { _ = JanetVM() }
        }
    }

    @Test func trapsWhenUsedFromAnotherThread() async {
        await #expect(processExitsWith: .failure) {
            let vm = makeVMOnItsOwnThread()
            _ = try? vm.pointee!.eval("(+ 1 2)")
        }
    }

    @Test func allowsANewVMAfterThePreviousOneIsReleased() {
        runOnOneThread {
            #expect(try! JanetVM().eval("(+ 1 2)") == .number(3))
            #expect(try! JanetVM().eval("(+ 2 2)") == .number(4))
        }
    }
}

/// Creates a VM on a thread of its own and leaves it there, alive.
private func makeVMOnItsOwnThread() -> UnsafeMutablePointer<JanetVM?> {
    nonisolated(unsafe) let slot = UnsafeMutablePointer<JanetVM?>.allocate(capacity: 1)
    slot.initialize(to: nil)
    let ready = DispatchSemaphore(value: 0)
    let thread = Thread {
        slot.pointee = JanetVM()
        ready.signal()
        while true { Thread.sleep(forTimeInterval: 60) }
    }
    thread.stackSize = executorThreadStackSize
    thread.start()
    ready.wait()
    return slot
}

/// Runs `body` to completion on a thread that hosts no other test's VM.
private func runOnOneThread(_ body: @escaping @Sendable () -> Void) {
    let done = DispatchSemaphore(value: 0)
    let thread = Thread {
        body()
        done.signal()
    }
    thread.stackSize = executorThreadStackSize
    thread.start()
    done.wait()
}
