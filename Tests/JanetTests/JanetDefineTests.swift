import Janet
import Testing

@Suite(.serialized)
struct JanetDefineTests {
    @Test func roundTripsEveryModeledValueThroughTheVM() throws {
        let janet = JanetRuntime()
        let value: JanetValue = .table([
            .keyword("scalars"): .tuple([.nil, .boolean(false), .number(2.5), .string("s"), .symbol("sym")]),
            .string("nested"): .array([.struct([.number(1): .keyword("one")])]),
        ])
        janet.define("value", value)
        #expect(try janet.eval("value") == value)
    }

    @Test func definedValuesAreUsableFromJanet() throws {
        let janet = JanetRuntime()
        janet.define("greeting", .string("hello"), documentation: "A test string.")
        #expect(try janet.eval("(string greeting \", world\")") == .string("hello, world"))
        #expect(try janet.eval("(get (dyn 'greeting) :doc)") == .string("A test string."))
    }

    @Test func survivesGarbageCollection() throws {
        let janet = JanetRuntime()
        janet.define("keep", .array([.string("x")]))
        #expect(try janet.eval("(do (gccollect) keep)") == .array([.string("x")]))
    }
}
