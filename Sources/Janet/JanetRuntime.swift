/// One Janet VM, driven from a dedicated thread.
///
/// Every call runs on the runtime's own thread, so Janet's thread-local VM state is
/// only ever touched from there. Each runtime owns one thread and one VM; create as
/// many as you need. The VM and its thread go away with the runtime.
public actor JanetRuntime {
    private let executor: ThreadExecutor
    private var vm: JanetVM?

    public nonisolated var unownedExecutor: UnownedSerialExecutor {
        executor.asUnownedSerialExecutor()
    }

    public init(name: String = "JanetRuntime") {
        executor = ThreadExecutor(name: name)
    }

    isolated deinit {
        vm = nil
    }

    /// Parses, compiles and runs `source`, returning the value of its last form.
    @discardableResult
    public func eval(_ source: String, sourceName: String = "swift") throws(JanetError) -> JanetValue {
        try activeVM().eval(source, sourceName: sourceName)
    }

    /// Binds `value` to `name` in the core environment so later evaluations can refer to it.
    public func define(_ name: String, _ value: JanetValue, documentation: String? = nil) {
        activeVM().define(name, value, documentation: documentation)
    }

    /// The VM is created on first use because `init` runs on the caller's thread.
    private func activeVM() -> JanetVM {
        if let vm { return vm }
        let vm = JanetVM()
        self.vm = vm
        return vm
    }
}
