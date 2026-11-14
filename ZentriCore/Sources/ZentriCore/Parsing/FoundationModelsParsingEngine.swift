import Foundation

/// Parses messages with the on-device model, then validates its answer like any other draft.
///
/// The model's output is never trusted directly: the direction must be `debit` or `credit`,
/// the amount and balance are read by ``AmountNormalizer``, the date by the shared date
/// parsers, and the resulting draft goes through ``TransactionValidator``. A message the
/// model cannot read becomes a ``ParseResult/failure(_:)`` with a diagnostic, never a
/// partially filled transaction.
public struct FoundationModelsParsingEngine: TransactionParsing, Sendable {
    /// The same message limit the rule engine applies, so neither engine spends work on a
    /// message the other would reject.
    private static let maximumTextLength = RegexParsingEngine.maximumTextLength

    /// The ISO-8601 spellings the model is asked for, most specific first.
    ///
    /// Only these formats are tried: a date-only fallback list would read an ISO timestamp
    /// as a different day, so the shape of the value decides how it is read. Every candidate
    /// goes through ``DateParser``, which keeps the fixed locale, calendar, time zone, and
    /// 2000–2099 year window the rest of parsing uses.
    private static let iso8601Formats = [
        "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ",
        "yyyy-MM-dd'T'HH:mm:ssZZZZZ",
        "yyyy-MM-dd'T'HH:mm:ss",
        "yyyy-MM-dd'T'HH:mm",
        "yyyy-MM-dd HH:mm:ss",
        "yyyy-MM-dd HH:mm",
        "yyyy-MM-dd",
    ]

    private let client: any TransactionModelClient

    public init(client: any TransactionModelClient) {
        self.client = client
    }

    public func parse(_ input: ParseInput) async -> ParseResult {
        guard input.text.count <= Self.maximumTextLength else {
            return .failure([ParseDiagnostic(
                code: .inputTooLong,
                field: "text",
                message: "The message is longer than \(Self.maximumTextLength) characters and was not parsed."
            )])
        }

        if case .unavailable(let reason) = await client.availability() {
            return .failure([ParseDiagnostic(
                code: .modelUnavailable,
                field: "model",
                message: reason.isEmpty ? Self.unavailableMessage : reason
            )])
        }

        do {
            let output = try await client.parse(text: input.text)
            return result(from: output, receivedAt: input.receivedAt)
        } catch {
            return .failure([Self.diagnostic(for: error)])
        }
    }

    /// The draft the model's answer describes, or the reason it cannot become one.
    private func result(from output: ModelTransactionOutput, receivedAt: Date) -> ParseResult {
        guard output.isTransaction else { return .notTransaction }

        guard let directionText = Self.trimmed(output.direction) else {
            return .failure([ParseDiagnostic(
                code: .missingField,
                field: "direction",
                message: "The message does not state whether money left or arrived."
            )])
        }
        guard let direction = Direction(rawValue: directionText.lowercased()) else {
            return .failure([ParseDiagnostic(
                code: .missingField,
                field: "direction",
                message: "The extracted direction is not a debit or a credit."
            )])
        }
        guard let amountText = Self.trimmed(output.amount) else {
            return .failure([ParseDiagnostic(
                code: .missingField,
                field: "amount",
                message: "The message does not state an amount."
            )])
        }
        guard let amount = AmountNormalizer.decimal(from: amountText) else {
            return .failure([ParseDiagnostic(
                code: .invalidAmount,
                field: "amount",
                message: "The extracted amount is not a number."
            )])
        }

        let draft = TransactionDraft(
            direction: direction,
            amount: amount,
            merchant: Self.trimmed(output.merchant) ?? "",
            balanceAfter: AmountNormalizer.decimal(from: output.balance),
            occurredAt: occurredAt(from: output.date, receivedAt: receivedAt),
            categorySuggestion: Self.trimmed(output.category)
        )
        switch TransactionValidator.validate(draft, receivedAt: receivedAt) {
        case .success(let validated):
            return .transaction(validated)
        case .failure(let failure):
            return .failure(failure.diagnostics)
        }
    }

    /// The message date as an instant, or the receipt time when it is missing or unreadable.
    ///
    /// The receipt time is the same fallback the rule engine uses, so a bad date never blocks
    /// an otherwise valid transaction.
    private func occurredAt(from raw: String?, receivedAt: Date) -> Date {
        guard let raw = Self.trimmed(raw) else { return receivedAt }
        for format in Self.iso8601Formats {
            if let date = DateParser.parse(raw, format: format) { return date }
        }
        return receivedAt
    }

    /// The diagnostic for a client failure.
    ///
    /// The underlying error is not described: a generation error can quote the message it was
    /// reading, and diagnostics never carry message text.
    private static func diagnostic(for error: any Error) -> ParseDiagnostic {
        switch error {
        case ModelClientError.timedOut, is CancellationError:
            ParseDiagnostic(
                code: .modelTimedOut,
                field: "model",
                message: "The on-device model did not answer in time."
            )
        default:
            ParseDiagnostic(
                code: .modelFailed,
                field: "model",
                message: "The on-device model could not read this message."
            )
        }
    }

    private static let unavailableMessage = "The on-device model is not available on this device."

    private static func trimmed(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
