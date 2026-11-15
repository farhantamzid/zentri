import Foundation

/// One named group a rule captured from a sample message.
public struct RuleCapture: Sendable, Equatable, Identifiable {
    /// The group's name, such as `amount` or `merchant`.
    public let name: String
    /// The captured text, exactly as it appears in the sample.
    public let value: String
    /// Where the capture sits in the sample, as character offsets, so the editor can highlight it.
    public let range: Range<Int>

    public var id: String { name }

    public init(name: String, value: String, range: Range<Int>) {
        self.name = name
        self.value = value
        self.range = range
    }
}

/// What one rule makes of a sample message: the groups it captured and the validated result.
public struct RulePreview: Sendable, Equatable {
    /// The named groups that took part in the first match, in pattern order. Empty when the
    /// pattern does not compile or does not match.
    public let captures: [RuleCapture]
    /// The parse the rule produces from the sample, with validation diagnostics on failure.
    public let result: ParseResult

    public init(captures: [RuleCapture], result: ParseResult) {
        self.captures = captures
        self.result = result
    }
}
