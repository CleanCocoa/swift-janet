import CJanet

/// A Janet value copied into Swift-owned storage.
///
/// Collections are copied recursively, so a `JanetValue` never references VM memory.
/// Values the VM can represent but this layer does not yet model (functions, fibers,
/// abstracts, buffers, ...) come through as `.unsupported` with Janet's type name.
public enum JanetValue: Hashable, Sendable {
    case `nil`
    case boolean(Bool)
    case number(Double)
    case string(String)
    case keyword(String)
    case symbol(String)
    case tuple([JanetValue])
    case array([JanetValue])
    case `struct`([JanetValue: JanetValue])
    case table([JanetValue: JanetValue])
    case unsupported(typeName: String)
}

/// Deepest container nesting a value may have when copied out of the VM.
///
/// Copying, hashing, comparing and releasing a `JanetValue` all recurse once per level,
/// and the release runs on whichever thread drops the value last, often a 512 KB
/// cooperative-pool thread. 256 sits at half the smallest depth measured to overflow one.
// TODO: Expose through JanetRuntime.init if a caller ever needs deeper values.
let maxValueNestingDepth = 256

extension JanetValue {
    /// Copies `raw` out of the VM. Must run on the thread that owns the VM.
    ///
    /// Throws with phase `.copy` when the value nests deeper than `maxValueNestingDepth`
    /// or contains a reference cycle through an array or table.
    init(raw: Janet) throws(JanetError) {
        var path = CopyPath()
        try self.init(raw: raw, path: &path)
    }

    private init(raw: Janet, path: inout CopyPath) throws(JanetError) {
        switch janet_type(raw) {
        case JANET_NIL:
            self = .nil
        case JANET_BOOLEAN:
            self = .boolean(janet_unwrap_boolean(raw) != 0)
        case JANET_NUMBER:
            self = .number(janet_unwrap_number(raw))
        case JANET_STRING:
            self = .string(String(janetBytes: janet_unwrap_string(raw)))
        case JANET_KEYWORD:
            self = .keyword(String(janetBytes: janet_unwrap_keyword(raw)))
        case JANET_SYMBOL:
            self = .symbol(String(janetBytes: janet_unwrap_symbol(raw)))
        case JANET_TUPLE:
            let tuple = janet_unwrap_tuple(raw)!
            let count = Int(janet_tuple_head(tuple).pointee.length)
            try path.enter(nil)
            self = .tuple(try Self.copy(elements: tuple, count: count, path: &path))
            path.leave(nil)
        case JANET_ARRAY:
            let pointer = janet_unwrap_array(raw)!
            let array = pointer.pointee
            try path.enter(pointer)
            self = .array(try Self.copy(elements: array.data, count: Int(array.count), path: &path))
            path.leave(pointer)
        case JANET_STRUCT:
            let st = janet_unwrap_struct(raw)!
            let capacity = janet_struct_head(st).pointee.capacity
            try path.enter(nil)
            self = .struct(try Self.copy(dictionary: st, capacity: capacity, path: &path))
            path.leave(nil)
        case JANET_TABLE:
            let pointer = janet_unwrap_table(raw)!
            let table = pointer.pointee
            try path.enter(pointer)
            self = .table(try Self.copy(dictionary: table.data, capacity: table.capacity, path: &path))
            path.leave(pointer)
        case let other:
            self = .unsupported(typeName: JanetValue.typeName(of: other))
        }
    }

    private static func copy(elements: UnsafePointer<Janet>, count: Int, path: inout CopyPath) throws(JanetError) -> [JanetValue] {
        var result: [JanetValue] = []
        result.reserveCapacity(count)
        for element in UnsafeBufferPointer(start: elements, count: count) {
            result.append(try JanetValue(raw: element, path: &path))
        }
        return result
    }

    private static func copy(dictionary kvs: UnsafePointer<JanetKV>, capacity: Int32, path: inout CopyPath) throws(JanetError) -> [JanetValue: JanetValue] {
        var result: [JanetValue: JanetValue] = [:]
        var kv = janet_dictionary_next(kvs, capacity, nil)
        while let entry = kv {
            result[try JanetValue(raw: entry.pointee.key, path: &path)] = try JanetValue(raw: entry.pointee.value, path: &path)
            kv = janet_dictionary_next(kvs, capacity, entry)
        }
        return result
    }

    /// The chain of containers currently being copied, from the root down.
    ///
    /// Only arrays and tables can form cycles; tuples and structs are immutable, so they
    /// count toward depth but are not tracked for revisits.
    private struct CopyPath {
        private var depth = 0
        private var mutableContainers: Set<UnsafeMutableRawPointer> = []

        mutating func enter(_ container: UnsafeMutableRawPointer?) throws(JanetError) {
            depth += 1
            if depth > maxValueNestingDepth {
                throw JanetError(phase: .copy, message: "value nested deeper than \(maxValueNestingDepth) levels")
            }
            if let container, !mutableContainers.insert(container).inserted {
                throw JanetError(phase: .copy, message: "value contains a cycle")
            }
        }

        mutating func leave(_ container: UnsafeMutableRawPointer?) {
            depth -= 1
            if let container { mutableContainers.remove(container) }
        }
    }
}

extension JanetValue {
    static func typeName(of type: JanetType) -> String {
        withUnsafePointer(to: janet_type_names) { tuple in
            tuple.withMemoryRebound(to: UnsafePointer<CChar>?.self, capacity: 16) { names in
                String(cString: names[Int(type.rawValue)]!)
            }
        }
    }
}

extension String {
    /// Decodes a Janet string/symbol/keyword, which is length-prefixed and may contain NUL bytes.
    init(janetBytes bytes: UnsafePointer<UInt8>) {
        let length = Int(janet_string_head(bytes).pointee.length)
        self = String(decoding: UnsafeBufferPointer(start: bytes, count: length), as: UTF8.self)
    }
}
