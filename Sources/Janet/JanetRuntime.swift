/// One Janet VM, driven from a dedicated thread.
///
/// Every call runs on the runtime's own thread, so Janet's thread-local VM state is
/// only ever touched from there. Each runtime owns one thread and one VM; create as
/// many as you need. The VM and its thread go away with the runtime.
public actor JanetRuntime {
    nonisolated let executor: ThreadExecutor
    /// Created on first isolated access, which is on the executor thread; `init` is not.
    private lazy var vm = JanetVM()

    public nonisolated var unownedExecutor: UnownedSerialExecutor {
        executor.asUnownedSerialExecutor()
    }

    public init(name: String = "JanetRuntime") {
        executor = ThreadExecutor(name: name)
    }

    /// Isolated so `vm` is released, and `janet_deinit` runs, on the executor thread.
    isolated deinit {
        executor.checkIsolated()
    }

    /// Parses, compiles and runs `source`, returning the value of its last form.
    @discardableResult
    public func eval(_ source: String, sourceName: String = "swift") throws(JanetError) -> JanetValue {
        try vm.eval(source, sourceName: sourceName)
    }

    /// Binds `value` to `name` in the core environment so later evaluations can refer to it.
    ///
    /// Throws with phase `.copy` when `value` nests deeper than `maxValueNestingDepth`.
    public func define(_ name: String, _ value: JanetValue, documentation: String? = nil) throws(JanetError) {
        try vm.define(name, value, documentation: documentation)
    }
}
