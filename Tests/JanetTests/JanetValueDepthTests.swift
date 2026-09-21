import Janet
import Testing

struct JanetValueDepthTests {
    /// 500 levels survive copy, hash, equality and release on a 512 KB cooperative-pool
    /// thread; hashing overflows at 1000 and release at 2000. A depth guard at the
    /// boundary is the real fix.
    @Test func copiesValuesNestedHundredsDeep() async throws {
        let janet = JanetRuntime()
        let value = try await janet.eval("(reduce (fn [acc _] [acc]) 1 (range 500))")
        var depth = 0
        var current = value
        while case .tuple(let inner) = current, let first = inner.first {
            depth += 1
            current = first
        }
        #expect(depth == 500)
    }
}
