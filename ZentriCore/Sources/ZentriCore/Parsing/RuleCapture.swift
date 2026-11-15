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
