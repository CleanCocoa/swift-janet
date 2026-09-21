import Janet
import Testing

struct JanetValueDepthTests {
    /// `(nested n)` builds n tuples inside each other around the number 1.
    private static let nested = "(defn nested [n] (reduce (fn [acc _] [acc]) 1 (range n)))"

    @Test func copiesValuesAtTheDepthLimit() async throws {
        let janet = JanetRuntime()
        let value = try await janet.eval("\(Self.nested) (nested 256)")
        var depth = 0
        var current = value
        while case .tuple(let inner) = current, let first = inner.first {
            depth += 1
            current = first
        }
        #expect(depth == 256)
        #expect(current == .number(1))
    }

    @Test func rejectsValuesPastTheDepthLimit() async {
        let janet = JanetRuntime()
        let error = await #expect(throws: JanetError.self) { try await janet.eval("\(Self.nested) (nested 257)") }
        #expect(error?.phase == .copy)
        #expect(error?.message == "value nested deeper than 256 levels")
    }

    @Test func rejectsCyclicTables() async {
        let janet = JanetRuntime()
        let error = await #expect(throws: JanetError.self) { try await janet.eval("(let [t @{}] (put t :self t) t)") }
        #expect(error?.phase == .copy)
        #expect(error?.message == "value contains a cycle")
    }

    @Test func rejectsCyclicArrays() async {
        let janet = JanetRuntime()
        let error = await #expect(throws: JanetError.self) { try await janet.eval("(let [a @[]] (array/push a a) a)") }
        #expect(error?.phase == .copy)
        #expect(error?.message == "value contains a cycle")
    }

    @Test func sharedSubvaluesAreNotCycles() async throws {
        let janet = JanetRuntime()
        let value = try await janet.eval("(let [a @[1]] @[a a])")
        #expect(value == .array([.array([.number(1)]), .array([.number(1)])]))
    }
}
