import Janet
import Testing

@Suite(.serialized)
struct JanetRuntimeTests {
    @Test func evaluatesScalars() throws {
        let janet = JanetRuntime()
        #expect(try janet.eval("(+ 1 2)") == .number(3))
        #expect(try janet.eval("nil") == .nil)
        #expect(try janet.eval("true") == .boolean(true))
        #expect(try janet.eval("(string \"a\" \"b\")") == .string("ab"))
        #expect(try janet.eval(":key") == .keyword("key"))
        #expect(try janet.eval("'sym") == .symbol("sym"))
    }

    @Test func reportsUnsupportedTypesByName() throws {
        let janet = JanetRuntime()
        #expect(try janet.eval("(fn [] 1)") == .unsupported(typeName: "function"))
    }

    @Test func throwsOnParseError() {
        let janet = JanetRuntime()
        let error = #expect(throws: JanetError.self) { try janet.eval("(+ 1") }
        #expect(error?.phase == .parse)
        #expect(error?.message.contains("parse error") == true)
    }

    @Test func throwsOnRuntimeError() {
        let janet = JanetRuntime()
        let error = #expect(throws: JanetError.self) { try janet.eval("(error \"boom\")") }
        #expect(error?.phase == .runtime)
        #expect(error?.message == "boom")
    }

    @Test func throwsOnCompileError() {
        let janet = JanetRuntime()
        let error = #expect(throws: JanetError.self) { try janet.eval("(undefined-symbol 1)") }
        #expect(error?.phase == .compile)
    }
}
