import Foundation

/// Reads the model's plain-text answer, one `field: value` per line, into the same fields guided
/// generation produces.
///
/// The plain-text form is the fallback for a message the guided request could not answer: guided
/// generation always runs the model's strictest content checks, which bank messages full of
/// amounts, card numbers, and balances can trip. A plain-text request can relax those checks,
/// and its answer is still only raw text here — ``FoundationModelsParsingEngine`` validates every
/// value exactly as it validates a guided answer, so nothing read this way is trusted more.
public enum ModelLineAnswer {
    /// The field names the plain-text prompt asks for, in order.
    public static let fields = ["isTransaction", "direction", "amount", "merchant", "balance", "date", "category"]

    /// The fields an answer states, or `nil` when it states nothing usable — such as a refusal
    /// written in prose instead of fields.
    public static func parse(_ answer: String) -> ModelTransactionOutput? {
        var values: [String: String] = [:]
        for line in answer.split(whereSeparator: \.isNewline) {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let key = normalizedKey(line[..<colon])
            guard let field = fields.first(where: { $0.lowercased() == key }) else { continue }
            let value = cleaned(line[line.index(after: colon)...])
            if values[field] == nil {
                values[field] = value
            }
        }
        guard let flag = values["isTransaction"].flatMap(boolean) else { return nil }
        return ModelTransactionOutput(
            isTransaction: flag,
            direction: values["direction"].flatMap(present),
            amount: values["amount"].flatMap(present),
            merchant: values["merchant"].flatMap(present),
            balance: values["balance"].flatMap(present),
            date: values["date"].flatMap(present),
            category: values["category"].flatMap(present)
        )
    }

    /// A key without the list markers, quotes, and spacing a model sometimes adds, lowercased.
    private static func normalizedKey(_ raw: Substring) -> String {
        raw.lowercased().filter { $0.isLetter }
    }

    /// A value without surrounding whitespace, quotes, or markdown emphasis.
    private static func cleaned(_ raw: Substring) -> String {
        raw.trimmingCharacters(in: .whitespaces.union(CharacterSet(charactersIn: "\"'`*")))
    }

    /// The value, or `nil` when the model wrote that the message does not state it.
    private static func present(_ value: String) -> String? {
        let lowered = value.lowercased()
        let empty = ["", "none", "null", "nil", "n/a", "na", "unknown", "-", "not stated"]
        return empty.contains(lowered) ? nil : value
    }

    private static func boolean(_ value: String) -> Bool? {
        switch value.lowercased() {
        case "yes", "true", "y": true
        case "no", "false", "n": false
        default: nil
        }
    }
}
