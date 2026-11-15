import Foundation

/// The rule engine and the on-device model run side by side on one sample message.
///
/// A side that was not asked for is `nil`, so the tester can tell "not run" apart from "ran and
/// found nothing". Timings are wall-clock milliseconds for that side's parse alone.
public struct RuleComparison: Sendable, Equatable {
    /// What the rules made of the message, or `nil` when only the model ran.
    public let ruleResult: ParseResult?
    /// What the model made of the message, or `nil` when only the rules ran.
    public let modelResult: ParseResult?
    /// How long the rules took, or `nil` when they did not run.
    public let ruleMilliseconds: Double?
    /// How long the model took, including its availability check, or `nil` when it did not run.
    public let modelMilliseconds: Double?
    /// Whether the model could run on this device, or `nil` when it was not asked.
    ///
    /// Hybrid ingestion folds an unavailable model into "not a transaction", so the tester reports
    /// availability on its own rather than leaving the person to infer it.
    public let modelAvailable: Bool?
    /// Every applicable rule whose pattern matched the message, in evaluation order, whether or not
    /// its match passed validation. More than one entry means rules compete for the message.
    public let matchingRuleIDs: [UUID]

    public init(
        ruleResult: ParseResult?,
        modelResult: ParseResult?,
        ruleMilliseconds: Double?,
        modelMilliseconds: Double?,
        modelAvailable: Bool?,
        matchingRuleIDs: [UUID]
    ) {
        self.ruleResult = ruleResult
        self.modelResult = modelResult
        self.ruleMilliseconds = ruleMilliseconds
        self.modelMilliseconds = modelMilliseconds
        self.modelAvailable = modelAvailable
        self.matchingRuleIDs = matchingRuleIDs
    }
}
