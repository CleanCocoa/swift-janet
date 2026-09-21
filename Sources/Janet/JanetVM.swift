import CJanet
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// One Janet VM with its core environment, bound to the thread that created it.
///
/// The VM state is thread-local: create, use, and release a `JanetVM` on one thread,
/// and keep at most one per thread at a time. `JanetRuntime` enforces this.
final class JanetVM {
    let env: UnsafeMutablePointer<JanetTable>
    private let thread: pthread_t

    /// - Precondition: no other `JanetVM` is live on the calling thread.
    init() {
        precondition(
            !threadHasLiveVM,
            "A JanetVM is already live on this thread; janet_init would clobber it"
        )
        threadHasLiveVM = true
        thread = pthread_self()
        janet_init()
        env = janet_core_env(nil)
    }

    deinit {
        precondition(isOnOwnThread, "JanetVM must be released on the thread that created it")
        janet_deinit()
        threadHasLiveVM = false
    }

    private var isOnOwnThread: Bool { pthread_equal(thread, pthread_self()) != 0 }

    /// Parses, compiles and runs `source`, returning the value of its last form.
    @discardableResult
    ///
    /// - Precondition: runs on the thread that created this VM.
    func eval(_ source: String, sourceName: String = "swift") throws(JanetError) -> JanetValue {
        precondition(isOnOwnThread, "JanetVM.eval must run on the thread that created the VM")
        var out = janet_wrap_nil()
        let flags = janet_dostring(env, source, sourceName, &out)
        if flags != 0 {
            throw JanetError(phase: .init(dostringFlags: flags), message: errorMessage(from: out))
        }
        return try JanetValue(raw: out)
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
    ///
    /// - Precondition: runs on the thread that created this VM.
    func define(_ name: String, _ value: JanetValue, documentation: String? = nil) throws(JanetError) {
        precondition(isOnOwnThread, "JanetVM.define must run on the thread that created the VM")
        janet_def(env, name, try value.makeRaw(), documentation)
    }
}

/// Per-thread marker for a live `JanetVM`, so a second `janet_init` on the thread traps.
private let liveVMKey: pthread_key_t = {
    var key = pthread_key_t()
    pthread_key_create(&key, nil)
    return key
}()

private var threadHasLiveVM: Bool {
    get { pthread_getspecific(liveVMKey) != nil }
    set { pthread_setspecific(liveVMKey, newValue ? UnsafeRawPointer(bitPattern: 1) : nil) }
}
