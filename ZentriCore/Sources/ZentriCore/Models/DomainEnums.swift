/// The direction money moved for a transaction.
public enum Direction: String, Codable, CaseIterable, Sendable {
    case debit
    case credit
}

/// The outcome of parsing a raw message.
public enum ParseStatus: String, Codable, CaseIterable, Sendable {
    case processing
    case parsed
    case ignored
    case failed
    case duplicate
}

/// The engine that produced a parse.
public enum ParseEngine: String, Codable, CaseIterable, Sendable {
    case rules
    case foundationModels
    case manual
}

/// How a balance checkpoint was established.
public enum CheckpointSource: String, Codable, CaseIterable, Sendable {
    case opening
    case sms
    case manual
}

/// How a transaction's category was assigned.
public enum CategorySource: String, Codable, CaseIterable, Sendable {
    case rule
    case ai
    case manual
    case `default`
}

/// The parser engine selected in settings.
public enum ParserMode: String, Codable, CaseIterable, Sendable {
    case rules
    case foundationModels
    case hybrid
}

/// How amounts are grouped and separated for display.
public enum NumberGrouping: String, Codable, CaseIterable, Sendable {
    /// Follow the locale's grouping, e.g. `1 000 000,00` or `1,000,000.00`.
    case system
    /// Three-digit groups throughout, e.g. `1,000,000.00`.
    case western
    /// Three-digit groups, then two-digit groups, e.g. `10,00,000.00`.
    case indian
}

/// How an imported backup replaces or merges existing data.
public enum ImportMode: String, Codable, CaseIterable, Sendable {
    case replace
    case merge
}
