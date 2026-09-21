/// Failure while parsing, compiling, or running code, or while copying its result into Swift.
public struct JanetError: Error, Equatable, CustomStringConvertible {
    public enum Phase: Equatable, Sendable {
        case parse, compile, runtime, copy
    }

    public let phase: Phase
    public let message: String

    public var description: String { message }
}
