import CJanet

/// One Janet VM with its core environment, bound to the thread that created it.
///
/// The VM state is thread-local: create, use, and release a `JanetVM` on one thread,
/// and keep at most one per thread at a time. `JanetRuntime` enforces this.
final class JanetVM {
    let env: UnsafeMutablePointer<JanetTable>

    init() {
        janet_init()
        env = janet_core_env(nil)
    }

    deinit {
        janet_deinit()
    }

    /// Parses, compiles and runs `source`, returning the value of its last form.
    @discardableResult
    func eval(_ source: String, sourceName: String = "swift") throws(JanetError) -> JanetValue {
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

@available(*, unavailable, message: "JanetVM is bound to the thread that created it")
extension JanetVM: Sendable {}

extension JanetError.Phase {
    init(dostringFlags flags: Int32) {
        if flags & JANET_DO_ERROR_PARSE != 0 { self = .parse }
        else if flags & JANET_DO_ERROR_COMPILE != 0 { self = .compile }
        else { self = .runtime }
    }
}

extension JanetVM {
    /// Binds `value` to `name` in the core environment so later evaluations can refer to it.
    func define(_ name: String, _ value: JanetValue, documentation: String? = nil) {
        janet_def(env, name, value.makeRaw(), documentation)
    }
}
