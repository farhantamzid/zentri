/// Runs the user's rules first and the on-device model second.
///
/// A validated rule transaction wins outright, so the model is never asked when the user's own
/// rules already explain the message. When the rules cannot produce a transaction the model
/// gets its turn, which is what makes hybrid mode useful for new bank formats.
///
/// When neither finds a transaction:
/// - the model saying the message is not a transaction is reported as
///   ``ParseResult/notTransaction``;
/// - the rules finding nothing while the model fails (a timeout, an error, a cancellation, or an
///   answer that fails validation) is reported as the model's failure, because "no rule matched"
///   is not evidence that the message is not a transaction: the message stays retryable;
/// - an unavailable model falls back to the rules' answer;
/// - both failing combines both failure lists so the UI can explain every problem.
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

        switch (rulesResult, modelResult) {
        case (.failure(let rulesDiagnostics), .failure(let modelDiagnostics)):
            return .failure(combinedDiagnostics(rulesDiagnostics, modelDiagnostics))
        case (.notTransaction, .failure(let modelDiagnostics)):
            // An unavailable model means hybrid runs on the rules alone, so their answer stands.
            let modelIsUnavailable = modelDiagnostics.allSatisfy { $0.code == .modelUnavailable }
            return modelIsUnavailable ? .notTransaction : .failure(modelDiagnostics)
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
