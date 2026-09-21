import Janet
import Testing

@MainActor
@Suite(.serialized)
struct MainJanetRuntimeTests {
    @Test func evaluatesScalars() throws {
        #expect(try JanetRuntime.main.eval("(+ 1 2)") == .number(3))
        #expect(try JanetRuntime.main.eval("(string \"a\" \"b\")") == .string("ab"))
    }

    @Test func definedValuesAreUsableFromJanet() throws {
        try JanetRuntime.main.define("main-greeting", .string("hello"))
        #expect(try JanetRuntime.main.eval("(string main-greeting \", world\")") == .string("hello, world"))
    }

    @Test func reportsFailurePhases() {
        #expect(performing: { try JanetRuntime.main.eval("(+ 1") }, throws: { ($0 as? JanetError)?.phase == .parse })
        #expect(performing: { try JanetRuntime.main.eval("(main-undefined 1)") }, throws: { ($0 as? JanetError)?.phase == .compile })
        #expect(performing: { try JanetRuntime.main.eval("(error \"boom\")") }, throws: { ($0 as? JanetError)?.phase == .runtime })
    }

    @Test func resetDiscardsDefinitions() throws {
        try JanetRuntime.main.define("main-resettable", .number(1))
        #expect(try JanetRuntime.main.eval("main-resettable") == .number(1))
        JanetRuntime.main.reset()
        #expect(performing: { try JanetRuntime.main.eval("main-resettable") }, throws: { ($0 as? JanetError)?.phase == .compile })
    }

    @Test func sharesOneInstance() {
        #expect(JanetRuntime.main === JanetRuntime.main)
    }
}
