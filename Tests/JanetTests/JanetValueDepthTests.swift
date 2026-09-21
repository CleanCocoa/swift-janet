import Janet
import Testing

struct JanetValueDepthTests {
    @Test func copiesValuesNestedThousandsDeep() async throws {
        let janet = JanetRuntime()
        let value = try await janet.eval("(reduce (fn [acc _] [acc]) 1 (range 2000))")
        var depth = 0
        var current = value
        while case .tuple(let inner) = current, let first = inner.first {
            depth += 1
            current = first
        }
        #expect(depth == 2000)
    }
}
