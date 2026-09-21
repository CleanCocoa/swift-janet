import CJanet

extension JanetValue {
    /// Allocates a VM-owned copy of this value. Must run on the thread that owns the VM.
    ///
    /// The result is not GC-rooted; hand it to the VM (define, call, put) before the
    /// next collection or root it yourself. Throws with phase `.copy` when the value
    /// nests deeper than `maxValueNestingDepth`.
    func makeRaw() throws(JanetError) -> Janet {
        try makeRaw(depth: 0)
    }

    private func makeRaw(depth: Int) throws(JanetError) -> Janet {
        switch self {
        case .nil:
            return janet_wrap_nil()
        case .boolean(let flag):
            return janet_wrap_boolean(flag ? 1 : 0)
        case .number(let number):
            return janet_wrap_number(number)
        case .string(let text):
            return withJanetBytes(text) { janet_wrap_string(janet_string($0, $1)) }
        case .keyword(let text):
            return withJanetBytes(text) { janet_wrap_keyword(janet_symbol($0, $1)) }
        case .symbol(let text):
            return withJanetBytes(text) { janet_wrap_symbol(janet_symbol($0, $1)) }
        case .tuple(let elements):
            let raws = try Self.makeRaws(elements, depth: depth)
            return janet_wrap_tuple(janet_tuple_n(raws, Int32(raws.count)))
        case .array(let elements):
            let raws = try Self.makeRaws(elements, depth: depth)
            return janet_wrap_array(janet_array_n(raws, Int32(raws.count)))
        case .struct(let entries):
            let inner = try Self.nest(depth)
            let st = janet_struct_begin(Int32(entries.count))
            for (key, value) in entries {
                janet_struct_put(st, try key.makeRaw(depth: inner), try value.makeRaw(depth: inner))
            }
            return janet_wrap_struct(janet_struct_end(st))
        case .table(let entries):
            let inner = try Self.nest(depth)
            let table = janet_table(Int32(entries.count))
            for (key, value) in entries {
                janet_table_put(table, try key.makeRaw(depth: inner), try value.makeRaw(depth: inner))
            }
            return janet_wrap_table(table)
        case .unsupported(let typeName):
            preconditionFailure("Cannot convert an unsupported Janet value of type \(typeName) back into the VM")
        }
    }
}

extension JanetValue {
    private static func makeRaws(_ elements: [JanetValue], depth: Int) throws(JanetError) -> [Janet] {
        let inner = try nest(depth)
        var raws: [Janet] = []
        raws.reserveCapacity(elements.count)
        for element in elements {
            raws.append(try element.makeRaw(depth: inner))
        }
        return raws
    }

    private static func nest(_ depth: Int) throws(JanetError) -> Int {
        if depth >= maxValueNestingDepth {
            throw JanetError(phase: .copy, message: "value nested deeper than \(maxValueNestingDepth) levels")
        }
        return depth + 1
    }
}

private func withJanetBytes(_ text: String, _ body: (UnsafePointer<UInt8>, Int32) -> Janet) -> Janet {
    var text = text
    return text.withUTF8 { body($0.baseAddress!, Int32($0.count)) }
}
