import Janet
import Testing

struct JanetDefineTests {
    @Test func roundTripsEveryModeledValueThroughTheVM() async throws {
        let janet = JanetRuntime()
        let value: JanetValue = .table([
            .keyword("scalars"): .tuple([.nil, .boolean(false), .number(2.5), .string("s"), .symbol("sym")]),
            .string("nested"): .array([.struct([.number(1): .keyword("one")])]),
        ])
        await janet.define("value", value)
        #expect(try await janet.eval("value") == value)
    }

    @Test func definedValuesAreUsableFromJanet() async throws {
        let janet = JanetRuntime()
        await janet.define("greeting", .string("hello"), documentation: "A test string.")
        #expect(try await janet.eval("(string greeting \", world\")") == .string("hello, world"))
        #expect(try await janet.eval("(get (dyn 'greeting) :doc)") == .string("A test string."))
    }

    @Test func survivesGarbageCollection() async throws {
        let janet = JanetRuntime()
        await janet.define("keep", .array([.string("x")]))
        #expect(try await janet.eval("(do (gccollect) keep)") == .array([.string("x")]))
    }
}
