import Janet
import Testing

struct JanetRuntimeTests {
    @Test func evaluatesScalars() async throws {
        let janet = JanetRuntime()
        #expect(try await janet.eval("(+ 1 2)") == .number(3))
        #expect(try await janet.eval("nil") == .nil)
        #expect(try await janet.eval("true") == .boolean(true))
        #expect(try await janet.eval("(string \"a\" \"b\")") == .string("ab"))
        #expect(try await janet.eval(":key") == .keyword("key"))
        #expect(try await janet.eval("'sym") == .symbol("sym"))
    }

    @Test func reportsUnsupportedTypesByName() async throws {
        let janet = JanetRuntime()
        #expect(try await janet.eval("(fn [] 1)") == .unsupported(typeName: "function"))
    }

    @Test func throwsOnParseError() async {
        let janet = JanetRuntime()
        let error = await #expect(throws: JanetError.self) { try await janet.eval("(+ 1") }
        #expect(error?.phase == .parse)
        #expect(error?.message.contains("parse error") == true)
    }

    @Test func throwsOnRuntimeError() async {
        let janet = JanetRuntime()
        let error = await #expect(throws: JanetError.self) { try await janet.eval("(error \"boom\")") }
        #expect(error?.phase == .runtime)
        #expect(error?.message == "boom")
    }

    @Test func throwsOnCompileError() async {
        let janet = JanetRuntime()
        let error = await #expect(throws: JanetError.self) { try await janet.eval("(undefined-symbol 1)") }
        #expect(error?.phase == .compile)
    }
}

struct JanetRuntimeIsolationTests {
    @Test func runtimesAreIndependentAndUsableConcurrently() async throws {
        let a = JanetRuntime(name: "a")
        let b = JanetRuntime(name: "b")
        await a.define("who", .string("a"))
        await b.define("who", .string("b"))
        async let fromA = a.eval("(do (var n 0) (for i 0 100000 (++ n)) who)")
        async let fromB = b.eval("(do (var n 0) (for i 0 100000 (++ n)) who)")
        #expect(try await fromA == .string("a"))
        #expect(try await fromB == .string("b"))
    }

    @Test func runtimeCanBeReleasedAndRecreated() async throws {
        for _ in 0..<5 {
            let janet = JanetRuntime()
            #expect(try await janet.eval("(+ 1 1)") == .number(2))
        }
    }
}
