/// One Janet VM that runs on the main thread, reached through `JanetRuntime.main`.
///
/// Calls are synchronous: they interpret on the caller's thread and block the UI for
/// their duration, which is what an editor that answers each keypress wants. The
/// process has exactly one instance, and every call shares its environment.
@MainActor
public final class MainJanetRuntime {
    private let vm: JanetVM

    fileprivate init() {
        vm = JanetVM()
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

extension JanetRuntime {
    /// The process-wide Janet VM on the main thread.
    @MainActor public static let main = MainJanetRuntime()
}
