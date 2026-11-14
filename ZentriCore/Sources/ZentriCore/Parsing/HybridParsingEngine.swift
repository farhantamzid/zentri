/// Runs the user's rules first and the on-device model second.
///
/// A validated rule transaction wins outright, so the model is never asked when the user's own
/// rules already explain the message. When the rules cannot produce a transaction the model
/// gets its turn, which is what makes hybrid mode useful for new bank formats. A
/// ``ParseResult/notTransaction`` is reported only when no engine found a transaction and at
/// least one engine said the message is not one; otherwise both failure lists are combined so
/// the UI can explain every problem.
public struct HybridParsingEngine: TransactionParsing, Sendable {
    private let rules: any TransactionParsing
    private let model: any TransactionParsing

    public init(rules: any TransactionParsing, model: any TransactionParsing) {
        self.rules = rules
        self.model = model
    }

    public func parse(_ input: ParseInput) async -> ParseResult {
        let rulesResult = await rules.parse(input)
        if case .transaction = rulesResult { return rulesResult }

        let modelResult = await model.parse(input)
        if case .transaction = modelResult { return modelResult }

        // Neither engine found a transaction. One engine calling the message not-a-transaction
        // is enough to agree with it; only when both failed are their diagnostics combined.
        switch (rulesResult, modelResult) {
        case (.failure(let rulesDiagnostics), .failure(let modelDiagnostics)):
            return .failure(combinedDiagnostics(rulesDiagnostics, modelDiagnostics))
        default:
            return .notTransaction
        }
    }

    /// Both engines' diagnostics in order, without repeating one they both reported.
    ///
    /// The engines share the same 20,000-character limit, so a message both reject as too long
    /// would otherwise list the same sentence twice.
    private func combinedDiagnostics(
        _ rulesDiagnostics: [ParseDiagnostic],
        _ modelDiagnostics: [ParseDiagnostic]
    ) -> [ParseDiagnostic] {
        var combined = rulesDiagnostics
        for diagnostic in modelDiagnostics where !combined.contains(diagnostic) {
            combined.append(diagnostic)
        }
        return combined
    }
}
