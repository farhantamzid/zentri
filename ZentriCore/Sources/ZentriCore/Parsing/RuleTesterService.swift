import Foundation

/// Runs rules and the on-device model against a sample message without saving anything.
///
/// The tester has no store at all: it takes rule specs and text and returns what the engines made
/// of them, so testing a message can never create a transaction, a message, or a checkpoint.
///
/// The service coordinates on the main actor, but every parse and match runs off it. A rule pattern
/// is user input, and a pattern that backtracks badly can take a very long time on the wrong text;
/// Swift's `Regex` does not check for cancellation while it matches, so the work is moved where it
/// cannot freeze the interface. The caller cancels a run it no longer needs and ignores its result —
/// the cancelled match still finishes on its background thread, which is the limit of this
/// approach. The 20,000-character message limit bounds the input either way.
@MainActor
public final class RuleTesterService {
    private let parserBuilder: any ParserBuilding
    private let now: @Sendable () -> Date

    /// Creates the tester.
    ///
    /// - Parameters:
    ///   - parserBuilder: The same builder ingestion uses, so a test parses exactly as capture would.
    ///   - now: The clock that stands in for the sample's receipt time.
    public init(parserBuilder: any ParserBuilding, now: @escaping @Sendable () -> Date = { .now }) {
        self.parserBuilder = parserBuilder
        self.now = now
    }

    /// Parses `text` with the rules, the model, or both side by side.
    ///
    /// - Parameters:
    ///   - text: The sample message, normalized the way ingestion normalizes it.
    ///   - accountID: The account to test as, which limits the rules to that account's; `nil` runs
    ///     every rule, as a capture without an account would.
    ///   - rules: The rules to test, in any order; the engine orders them.
    ///   - mode: ``ParserMode/rules`` runs the rules only, ``ParserMode/foundationModels`` the model
    ///     only, and ``ParserMode/hybrid`` both, separately, so their answers can be compared.
    public func test(text: String, accountID: UUID?, rules: [ParsingRuleSpec], mode: ParserMode) async -> RuleComparison {
        let input = ParseInput(
            text: MessageText.normalizedForParsing(text),
            accountID: accountID,
            receivedAt: now()
        )
        let ruleParser: (any TransactionParsing)? = mode == .foundationModels
            ? nil
            : parserBuilder.makeParser(for: .rules, rules: rules)
        let modelParser: (any TransactionParsing)? = mode == .rules
            ? nil
            : parserBuilder.makeParser(for: .foundationModels, rules: [])

        async let ruleRun = Self.timedParse(ruleParser, input: input)
        async let modelRun = Self.timedParse(modelParser, input: input)
        async let matching = Self.matchingRuleIDs(ruleParser == nil ? [] : rules, input: input)
        let (rules, model, matchingIDs) = await (ruleRun, modelRun, matching)

        return RuleComparison(
            ruleResult: rules?.result,
            modelResult: model?.result,
            ruleMilliseconds: rules?.milliseconds,
            modelMilliseconds: model?.milliseconds,
            modelAvailable: model.map { !Self.reportsUnavailableModel($0.result) },
            matchingRuleIDs: matchingIDs
        )
    }

    /// What one rule makes of a sample, for the rule editor's live preview.
    ///
    /// The rule is previewed as written: its on/off switch and account are ignored, so a rule that
    /// is off or belongs to another account still shows its captures.
    public func preview(rule: ParsingRuleSpec, text: String) async -> RulePreview {
        let spec = ParsingRuleSpec(
            id: rule.id,
            accountID: nil,
            direction: rule.direction,
            pattern: rule.pattern,
            dateFormat: rule.dateFormat,
            isCaseInsensitive: rule.isCaseInsensitive,
            dotMatchesNewlines: rule.dotMatchesNewlines,
            priority: rule.priority,
            isEnabled: true
        )
        return await Self.preview(spec, input: ParseInput(text: text, receivedAt: now()))
    }

    // MARK: - Off the main actor

    /// One parser's answer and how long it took.
    private struct TimedResult: Sendable {
        let result: ParseResult
        let milliseconds: Double
    }

    @concurrent
    private static func timedParse(_ parser: (any TransactionParsing)?, input: ParseInput) async -> TimedResult? {
        guard let parser else { return nil }
        let clock = ContinuousClock()
        let start = clock.now
        let result = await parser.parse(input)
        return TimedResult(result: result, milliseconds: milliseconds(start.duration(to: clock.now)))
    }

    @concurrent
    private static func matchingRuleIDs(_ rules: [ParsingRuleSpec], input: ParseInput) async -> [UUID] {
        guard !rules.isEmpty else { return [] }
        return RegexParsingEngine(rules: rules).matchingRuleIDs(for: input)
    }

    @concurrent
    private static func preview(_ spec: ParsingRuleSpec, input: ParseInput) async -> RulePreview {
        let captures = RegexParsingEngine.captures(for: spec, in: input.text)
        let result = await RegexParsingEngine(rules: [spec]).parse(input)
        return RulePreview(captures: captures, result: result)
    }

    // MARK: - Helpers

    private nonisolated static func milliseconds(_ duration: Duration) -> Double {
        let components = duration.components
        return Double(components.seconds) * 1_000 + Double(components.attoseconds) / 1e15
    }

    private static func reportsUnavailableModel(_ result: ParseResult) -> Bool {
        if case .failure(let diagnostics) = result {
            return diagnostics.contains { $0.code == .modelUnavailable }
        }
        return false
    }
}
