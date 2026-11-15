import Foundation

/// Parses messages with an ordered set of user-defined regex rules.
///
/// Rules run by ascending priority, then in the order they are supplied (their creation
/// order). A rule that matches but fails validation is recorded and the next rule runs, so a
/// broad rule cannot block a more precise one. The engine is pure and has no persistence or
/// UI dependency.
public struct RegexParsingEngine: TransactionParsing, Sendable {
    /// Messages longer than this are rejected before any pattern runs.
    public static let maximumTextLength = 20_000

    /// The merchant used when a rule captures none.
    private static let unknownMerchant = "Unknown merchant"

    private let rules: [ParsingRuleSpec]

    public init(rules: [ParsingRuleSpec]) {
        self.rules = rules
    }

    public func parse(_ input: ParseInput) async -> ParseResult {
        guard input.text.count <= Self.maximumTextLength else {
            return .failure([ParseDiagnostic(
                code: .inputTooLong,
                field: "text",
                message: "The message is longer than \(Self.maximumTextLength) characters and was not parsed."
            )])
        }

        var diagnostics: [ParseDiagnostic] = []
        for spec in orderedRules(for: input) {
            switch evaluate(spec, in: input) {
            case .notMatched:
                continue
            case .failed(let diagnostic):
                diagnostics.append(diagnostic)
            case .draft(let draft):
                switch TransactionValidator.validate(draft, receivedAt: input.receivedAt) {
                case .success(let validated):
                    return .transaction(validated)
                case .failure(let failure):
                    diagnostics.append(contentsOf: failure.diagnostics.map { $0.attributed(to: spec.id) })
                }
            }
        }

        return diagnostics.isEmpty ? .notTransaction : .failure(diagnostics)
    }

    /// The applicable rules whose pattern matches the message, in evaluation order.
    ///
    /// A rule is listed whether or not its match would pass validation, so the tester can show
    /// rules competing for one message. A pattern that does not compile matches nothing.
    public func matchingRuleIDs(for input: ParseInput) -> [UUID] {
        guard input.text.count <= Self.maximumTextLength else { return [] }
        return orderedRules(for: input).compactMap { spec in
            guard let regex = try? Self.compiled(spec),
                  (try? regex.firstMatch(in: input.text)) != nil else { return nil }
            return spec.id
        }
    }

    /// The named groups `spec` captures in its first match of `text`, in pattern order.
    ///
    /// The rule's switch and account are ignored: the editor previews the rule being edited
    /// whatever its state. A pattern that does not compile or does not match captures nothing.
    public static func captures(for spec: ParsingRuleSpec, in text: String) -> [RuleCapture] {
        guard text.count <= maximumTextLength,
              let regex = try? compiled(spec),
              let match = try? regex.firstMatch(in: text) else { return [] }
        return match.output.compactMap { element in
            guard let name = element.name, let range = element.range else { return nil }
            let lower = text.distance(from: text.startIndex, to: range.lowerBound)
            let upper = lower + text.distance(from: range.lowerBound, to: range.upperBound)
            return RuleCapture(name: name, value: String(text[range]), range: lower..<upper)
        }
    }

    /// The rule's pattern compiled with its flags.
    private static func compiled(_ spec: ParsingRuleSpec) throws -> Regex<AnyRegexOutput> {
        try Regex(spec.pattern)
            .ignoresCase(spec.isCaseInsensitive)
            .dotMatchesNewlines(spec.dotMatchesNewlines)
    }

    /// The enabled rules that apply to the input, in evaluation order.
    private func orderedRules(for input: ParseInput) -> [ParsingRuleSpec] {
        rules.enumerated()
            .filter { entry in
                guard entry.element.isEnabled else { return false }
                guard let accountID = input.accountID else { return true }
                return entry.element.accountID == accountID
            }
            .sorted { lhs, rhs in
                if lhs.element.priority != rhs.element.priority {
                    return lhs.element.priority < rhs.element.priority
                }
                // `sorted(by:)` is not stable, so the supplied order is the explicit tiebreaker.
                return lhs.offset < rhs.offset
            }
            .map(\.element)
    }

    /// What running one rule produced.
    private enum RuleMatch {
        case notMatched
        case failed(ParseDiagnostic)
        case draft(TransactionDraft)
    }

    /// Compiles and runs one rule, turning a match into a draft or a diagnostic.
    private func evaluate(_ spec: ParsingRuleSpec, in input: ParseInput) -> RuleMatch {
        let regex: Regex<AnyRegexOutput>
        do {
            regex = try Self.compiled(spec)
        } catch {
            return .failed(ParseDiagnostic(
                code: .invalidPattern,
                ruleID: spec.id,
                field: "pattern",
                message: "The rule pattern is not a valid regular expression: \(error)"
            ))
        }

        let match: Regex<AnyRegexOutput>.Match?
        do {
            match = try regex.firstMatch(in: input.text)
        } catch {
            return .failed(ParseDiagnostic(
                code: .matchFailed,
                ruleID: spec.id,
                field: "pattern",
                message: "The rule pattern could not be matched against the message."
            ))
        }
        guard let match else { return .notMatched }

        // The amount group is required. A rule without one is only a failure for a message it
        // actually matches; otherwise it does not apply to this message.
        guard regex.contains(captureNamed: "amount") else {
            return .failed(ParseDiagnostic(
                code: .missingAmountGroup,
                ruleID: spec.id,
                field: "amount",
                message: "The rule pattern has no 'amount' capture group."
            ))
        }
        guard let amountText = capture("amount", in: match) else {
            return .failed(ParseDiagnostic(
                code: .missingField,
                ruleID: spec.id,
                field: "amount",
                message: "The rule matched but did not capture an amount."
            ))
        }
        guard let amount = AmountNormalizer.decimal(from: amountText) else {
            return .failed(ParseDiagnostic(
                code: .invalidAmount,
                ruleID: spec.id,
                field: "amount",
                message: "The captured amount is not a number."
            ))
        }

        let draft = TransactionDraft(
            direction: spec.direction,
            amount: amount,
            merchant: capture("merchant", in: match) ?? Self.unknownMerchant,
            balanceAfter: capture("balance", in: match).flatMap { AmountNormalizer.decimal(from: $0) },
            occurredAt: occurredAt(for: spec, match: match, receivedAt: input.receivedAt),
            reference: capture("reference", in: match),
            matchedRuleID: spec.id
        )
        return .draft(draft)
    }

    /// A non-empty captured value with surrounding whitespace removed.
    private func capture(_ name: String, in match: Regex<AnyRegexOutput>.Match) -> String? {
        guard let value = match[name]?.substring else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// The message date parsed with the rule's format, or the receipt time.
    ///
    /// A captured `time` group is combined with the date first, so a rule whose format
    /// includes hours and minutes keeps the time from the message. A rule without a format
    /// still reads the date: ``DateParser`` tries its common formats before the receipt time.
    private func occurredAt(
        for spec: ParsingRuleSpec,
        match: Regex<AnyRegexOutput>.Match,
        receivedAt: Date
    ) -> Date {
        guard let dateText = capture("date", in: match) else { return receivedAt }
        let format = spec.dateFormat?.trimmingCharacters(in: .whitespacesAndNewlines)

        if let format, !format.isEmpty,
           let timeText = capture("time", in: match),
           let combined = DateParser.parse("\(dateText) \(timeText)", format: format) {
            return combined
        }
        return DateParser.date(from: dateText, format: format, receivedAt: receivedAt) ?? receivedAt
    }
}

private extension ParseDiagnostic {
    /// The same diagnostic, attributed to the rule that produced it.
    func attributed(to ruleID: UUID) -> ParseDiagnostic {
        ParseDiagnostic(code: code, ruleID: ruleID, field: field, message: message)
    }
}
