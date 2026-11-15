import Foundation

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
