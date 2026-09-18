import CJanet
import Testing

@Suite(.serialized)
struct CJanetSmokeTests {
    @Test func evaluatesArithmeticThroughRawCAPI() {
        janet_init()
        defer { janet_deinit() }

        let env = janet_core_env(nil)
        var result = janet_wrap_nil()
        let status = janet_dostring(env, "(+ 1 2)", "test", &result)

        #expect(status == 0)
        #expect(janet_checktype(result, JANET_NUMBER) != 0)
        #expect(janet_unwrap_number(result) == 3)
    }
}
