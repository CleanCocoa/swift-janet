import Foundation

/// Stack size for executor threads, matching the macOS main thread.
///
/// Darwin gives secondary threads 512 KB by default, and copying a nested `JanetValue`
/// only a few hundred levels deep overflowed that. The main thread gets 8 MB, which is
/// what the VM ran on before it moved to its own thread. The space is reserved, not
/// committed, so the cost is address space rather than memory.
// TODO: Expose through JanetRuntime.init if a caller ever needs a different size.
let executorThreadStackSize = 8 << 20

/// A serial executor that runs every job on one dedicated OS thread.
///
/// Actors backed by this executor are pinned to a single thread, which is what
/// thread-local C state such as the Janet VM requires. The thread exits when the
/// executor is deallocated.
final class ThreadExecutor: SerialExecutor {
    private let state = SharedState()
    private let threadName: String

    init(name: String) {
        threadName = name
        let state = self.state
        let thread = Thread { state.run() }
        thread.name = name
        thread.stackSize = executorThreadStackSize
        thread.start()
    }

    deinit {
        state.stop()
    }

    var isCurrentThread: Bool { state.isCurrentThread }

    /// Runs `body` on the executor thread right before it exits.
    func onThreadExit(_ body: @escaping @Sendable () -> Void) {
        state.onExit = body
    }

    func enqueue(_ job: consuming ExecutorJob) {
        state.enqueue(UnownedJob(job), on: self)
    }

    func asUnownedSerialExecutor() -> UnownedSerialExecutor {
        UnownedSerialExecutor(ordinary: self)
    }

    func isIsolatingCurrentContext() -> Bool? {
        isCurrentThread
    }

    func checkIsolated() {
        precondition(isCurrentThread, "Expected to run on thread \(threadName)")
    }

    /// Job queue owned by the thread. It retains the executor only while a job for it is
    /// queued or running, so the executor's last release can happen inside one of its own
    /// jobs without the job's executor reference dangling.
    private final class SharedState: @unchecked Sendable {
        private let condition = NSCondition()
        private var jobs: [(UnownedJob, ThreadExecutor)] = []
        private var stopped = false
        private var thread: pthread_t?
        var onExit: (@Sendable () -> Void)?

        var isCurrentThread: Bool {
            condition.lock()
            defer { condition.unlock() }
            guard let thread else { return false }
            return pthread_equal(thread, pthread_self()) != 0
        }

        func enqueue(_ job: UnownedJob, on executor: ThreadExecutor) {
            condition.lock()
            jobs.append((job, executor))
            condition.signal()
            condition.unlock()
        }

        func stop() {
            condition.lock()
            stopped = true
            condition.signal()
            condition.unlock()
        }

        func run() {
            condition.lock()
            thread = pthread_self()
            condition.unlock()
            while true {
                condition.lock()
                while jobs.isEmpty && !stopped { condition.wait() }
                let batch = jobs
                jobs.removeAll()
                let shouldExit = batch.isEmpty && stopped
                let onExit = shouldExit ? self.onExit : nil
                condition.unlock()
                if shouldExit {
                    onExit?()
                    return
                }
                for (job, executor) in batch {
                    job.runSynchronously(on: executor.asUnownedSerialExecutor())
                }
            }
        }
    }
}
