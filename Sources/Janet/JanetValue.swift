import CJanet

/// A Janet value copied into Swift-owned storage.
///
/// Values the VM can represent but this layer does not yet model (functions, fibers,
/// abstracts, buffers, ...) come through as `.unsupported` with Janet's type name.
public enum JanetValue: Equatable, Sendable {
    case `nil`
    case boolean(Bool)
    case number(Double)
    case string(String)
    case keyword(String)
    case symbol(String)
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
        case let other:
            self = .unsupported(typeName: JanetValue.typeName(of: other))
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
