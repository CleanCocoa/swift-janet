/// Failure reported by the Janet VM while parsing, compiling, or running code.
public struct JanetError: Error, Equatable, CustomStringConvertible {
    public enum Phase: Equatable, Sendable {
        case parse, compile, runtime
    }

    public let phase: Phase
    public let message: String

    public var description: String { message }
}
