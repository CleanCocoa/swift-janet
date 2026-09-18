import CJanet

/// One Janet VM with its core environment.
///
/// The VM state is thread-local: use the runtime only on the thread that created it,
/// and create at most one runtime per thread at a time.
public final class JanetRuntime {
    let env: UnsafeMutablePointer<JanetTable>

    public init() {
        janet_init()
        env = janet_core_env(nil)
    }

    deinit {
        janet_deinit()
    }

    /// Parses, compiles and runs `source`, returning the value of its last form.
    @discardableResult
    public func eval(_ source: String, sourceName: String = "swift") throws(JanetError) -> JanetValue {
        var out = janet_wrap_nil()
        let flags = janet_dostring(env, source, sourceName, &out)
        if flags != 0 {
            throw JanetError(phase: .init(dostringFlags: flags), message: errorMessage(from: out))
        }
        return JanetValue(raw: out)
    }

    private func errorMessage(from raw: Janet) -> String {
        if janet_checktype(raw, JANET_STRING) != 0 {
            return String(janetBytes: janet_unwrap_string(raw))
        }
        return String(janetBytes: janet_to_string(raw))
    }
}

@available(*, unavailable, message: "JanetRuntime is bound to the thread that created it")
extension JanetRuntime: Sendable {}

extension JanetError.Phase {
    init(dostringFlags flags: Int32) {
        if flags & JANET_DO_ERROR_PARSE != 0 { self = .parse }
        else if flags & JANET_DO_ERROR_COMPILE != 0 { self = .compile }
        else { self = .runtime }
    }
}

extension JanetRuntime {
    /// Binds `value` to `name` in the core environment so later evaluations can refer to it.
    public func define(_ name: String, _ value: JanetValue, documentation: String? = nil) {
        janet_def(env, name, value.makeRaw(), documentation)
    }
}
