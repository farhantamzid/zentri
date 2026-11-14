/// Builds the parser a settings mode asks for.
///
/// Ingestion and the rule editor depend on this protocol rather than on ``ParserFactory``, so
/// tests can supply a builder whose parsers are scripted.
public protocol ParserBuilding: Sendable {
    /// The parser for `mode`, reading messages with `rules` where the mode uses them.
    func makeParser(for mode: ParserMode, rules: [ParsingRuleSpec]) -> any TransactionParsing
}

/// Builds the rule, on-device model, or hybrid parser.
///
/// The model client is created once and shared by every parser the factory builds, so the live
/// client is not recreated for each message. A model that is unavailable is not filtered out
/// here: the engine returns ``ParseDiagnostic/Code/modelUnavailable`` so the UI can explain the
/// device state instead of silently falling back to the rules.
public struct ParserFactory: ParserBuilding {
    private let modelClient: any TransactionModelClient

    public init(modelClient: any TransactionModelClient) {
        self.modelClient = modelClient
    }

    public func makeParser(for mode: ParserMode, rules: [ParsingRuleSpec]) -> any TransactionParsing {
        switch mode {
        case .rules:
            RegexParsingEngine(rules: rules)
        case .foundationModels:
            FoundationModelsParsingEngine(client: modelClient)
        case .hybrid:
            HybridParsingEngine(
                rules: RegexParsingEngine(rules: rules),
                model: FoundationModelsParsingEngine(client: modelClient)
            )
        }
    }
}
