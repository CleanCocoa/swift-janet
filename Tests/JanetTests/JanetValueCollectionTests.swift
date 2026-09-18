import Janet
import Testing

@Suite(.serialized)
struct JanetValueCollectionTests {
    @Test func copiesTuplesAndArrays() throws {
        let janet = JanetRuntime()
        #expect(try janet.eval("[1 \"two\" :three]") == .tuple([.number(1), .string("two"), .keyword("three")]))
        #expect(try janet.eval("@[1 [2 3]]") == .array([.number(1), .tuple([.number(2), .number(3)])]))
        #expect(try janet.eval("[]") == .tuple([]))
    }

    @Test func copiesStructsAndTables() throws {
        let janet = JanetRuntime()
        #expect(try janet.eval("{:a 1 :b [2]}") == .struct([.keyword("a"): .number(1), .keyword("b"): .tuple([.number(2)])]))
        let table = try janet.eval("(let [t @{}] (put t 1 :one) (put t 2 :two) (put t 2 nil) t)")
        #expect(table == .table([.number(1): .keyword("one")]))
    }
}
