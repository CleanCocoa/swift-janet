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

extension JanetValue {
    /// Copies `raw` out of the VM. Must run on the thread that owns the VM.
    init(raw: Janet) {
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
            self = .tuple(Self.copy(elements: tuple, count: count))
        case JANET_ARRAY:
            let array = janet_unwrap_array(raw)!.pointee
            self = .array(Self.copy(elements: array.data, count: Int(array.count)))
        case JANET_STRUCT:
            let st = janet_unwrap_struct(raw)!
            let capacity = janet_struct_head(st).pointee.capacity
            self = .struct(Self.copy(dictionary: st, capacity: capacity))
        case JANET_TABLE:
            let table = janet_unwrap_table(raw)!.pointee
            self = .table(Self.copy(dictionary: table.data, capacity: table.capacity))
        case let other:
            self = .unsupported(typeName: JanetValue.typeName(of: other))
        }
    }

    private static func copy(elements: UnsafePointer<Janet>, count: Int) -> [JanetValue] {
        UnsafeBufferPointer(start: elements, count: count).map(JanetValue.init(raw:))
    }

    private static func copy(dictionary kvs: UnsafePointer<JanetKV>, capacity: Int32) -> [JanetValue: JanetValue] {
        var result: [JanetValue: JanetValue] = [:]
        var kv = janet_dictionary_next(kvs, capacity, nil)
        while let entry = kv {
            result[JanetValue(raw: entry.pointee.key)] = JanetValue(raw: entry.pointee.value)
            kv = janet_dictionary_next(kvs, capacity, entry)
        }
        return result
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
