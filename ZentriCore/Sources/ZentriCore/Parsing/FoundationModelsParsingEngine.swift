import Foundation

/// Parses messages with the on-device model, then validates its answer like any other draft.
///
/// The model's output is never trusted directly: the direction must be `debit` or `credit`,
/// the amount must be a value the message itself states, the balance is read by
/// ``AmountNormalizer``, the date by the shared date parsers, and the resulting draft goes
/// through ``TransactionValidator``. A message the model cannot read becomes a
/// ``ParseResult/failure(_:)`` with a diagnostic, never a partially filled transaction.
public struct FoundationModelsParsingEngine: TransactionParsing, Sendable {
    /// The same message limit the rule engine applies, so neither engine spends work on a
    /// message the other would reject.
    private static let maximumTextLength = RegexParsingEngine.maximumTextLength

    /// The longest merchant name accepted from the model, in characters.
    ///
    /// A generation that rambles is cut here rather than rejected: the amount and date still
    /// describe a real transaction. Validation's whitespace collapsing runs afterwards, so the
    /// stored name is never longer than this.
    private static let maximumMerchantLength = 120

    /// The ISO-8601 spellings the model is asked for, most specific first.
    ///
    /// The offset is accepted both in the extended form (`+08:00`) and in the basic form
    /// (`+0800`), with and without fractional seconds. Only these formats are tried: a
    /// date-only fallback list would read an ISO timestamp as a different day, so the shape of
    /// the value decides how it is read. Every candidate goes through ``DateParser``, which
    /// keeps the fixed locale, calendar, and 2000–2099 year window the rest of parsing uses; a
    /// value without an offset is read in the engine's time zone, like a rule's date.
    private static let iso8601Formats = [
        "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ",
        "yyyy-MM-dd'T'HH:mm:ssZZZZZ",
        "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
        "yyyy-MM-dd'T'HH:mm:ssZ",
        "yyyy-MM-dd'T'HH:mm:ss",
        "yyyy-MM-dd'T'HH:mm",
        "yyyy-MM-dd HH:mm:ss",
        "yyyy-MM-dd HH:mm",
        "yyyy-MM-dd",
    ]

    private let client: any TransactionModelClient
    /// The zone a date without an explicit offset is read in.
    private let timeZone: TimeZone

    /// - Parameters:
    ///   - client: The on-device model.
    ///   - timeZone: The zone a date without an offset is read in; the device's own by default,
    ///     because a bank message states local time.
    public init(client: any TransactionModelClient, timeZone: TimeZone = .autoupdatingCurrent) {
        self.client = client
        self.timeZone = timeZone
    }

    public func parse(_ input: ParseInput) async -> ParseResult {
        // Cancellation is a caller decision, not a model failure, so it is reported as itself
        // before any work starts.
        guard !Task.isCancelled else { return .failure([Self.cancelledDiagnostic]) }

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
            // A client can finish just as the caller cancels: that answer is stale, so it is
            // reported as cancelled instead of being turned into a transaction.
            guard !Task.isCancelled else { return .failure([Self.cancelledDiagnostic]) }
            return result(from: output, text: input.text, receivedAt: input.receivedAt)
        } catch {
            return .failure([Self.diagnostic(for: error)])
        }
    }

    /// The draft the model's answer describes, or the reason it cannot become one.
    private func result(from output: ModelTransactionOutput, text: String, receivedAt: Date) -> ParseResult {
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

        // The model may only report a value the message itself states: a hallucinated or
        // injected number would otherwise become a transaction.
        guard Self.messageAmounts(from: text).contains(amount) else {
            return .failure([ParseDiagnostic(
                code: .invalidAmount,
                field: "amount",
                message: "The extracted amount does not appear in the message."
            )])
        }

        let draft = TransactionDraft(
            direction: direction,
            amount: amount,
            merchant: Self.truncated(Self.trimmed(output.merchant) ?? "", to: Self.maximumMerchantLength),
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
            if let date = DateParser.parse(raw, format: format, timeZone: timeZone) {
                return DateParser.hasTime(format)
                    ? date
                    : DateParser.preferringReceipt(date, receivedAt: receivedAt, timeZone: timeZone)
            }
        }
        return receivedAt
    }

    /// Every amount the message itself states, read the way the rule engine reads one.
    ///
    /// A candidate is a run of digits and separators between other characters, and also each
    /// whitespace-separated piece of such a run, so `1,234.50` and a space-grouped `1 234.50`
    /// are both read. Values are compared as parsed `Decimal`s, never as text: a digit-substring
    /// test would let `100` match `1,000`.
    private static func messageAmounts(from text: String) -> Set<Decimal> {
        var amounts: Set<Decimal> = []
        for chunk in text.split(whereSeparator: { !isAmountCharacter($0) }) {
            for candidate in [chunk[...]] + chunk.split(whereSeparator: \.isWhitespace) {
                guard let digits = digitSpan(of: candidate),
                      let amount = AmountNormalizer.decimal(from: String(digits)) else { continue }
                amounts.insert(amount)
            }
        }
        return amounts
    }

    /// Whether the character can appear inside an amount: a digit, a separator, or the
    /// whitespace some messages group thousands with.
    private static func isAmountCharacter(_ character: Character) -> Bool {
        isASCIIDigit(character) || character == "," || character == "." || character.isWhitespace
    }

    /// Whether the character is an ASCII digit, matching ``AmountNormalizer``'s rule.
    private static func isASCIIDigit(_ character: Character) -> Bool {
        character.isASCII && character.isNumber
    }

    /// The part of a candidate from its first digit to its last, so surrounding punctuation is
    /// ignored.
    private static func digitSpan(of candidate: Substring) -> Substring? {
        guard let first = candidate.firstIndex(where: isASCIIDigit),
              let last = candidate.lastIndex(where: isASCIIDigit),
              first <= last else { return nil }
        return candidate[first...last]
    }

    /// `value` cut to at most `limit` characters, never failing.
    private static func truncated(_ value: String, to limit: Int) -> String {
        value.count <= limit ? value : String(value.prefix(limit))
    }

    /// The diagnostic for a client failure.
    ///
    /// The underlying error is not described: a generation error can quote the message it was
    /// reading, and diagnostics never carry message text.
    private static func diagnostic(for error: any Error) -> ParseDiagnostic {
        switch error {
        case is CancellationError:
            cancelledDiagnostic
        case ModelClientError.timedOut:
            timedOutDiagnostic
        case ModelClientError.unsupportedLanguage:
            unsupportedLanguageDiagnostic
        default:
            // A client can surface cancellation with its own error type; a cancelled task still
            // means "try again", not "the model failed".
            Task.isCancelled ? cancelledDiagnostic : failedDiagnostic
        }
    }

    /// The diagnostic for a parse the caller cancelled.
    private static let cancelledDiagnostic = ParseDiagnostic(
        code: .cancelled,
        field: "model",
        message: "Parsing was cancelled."
    )

    /// The diagnostic for a generation that outlived the client's time limit.
    private static let timedOutDiagnostic = ParseDiagnostic(
        code: .modelTimedOut,
        field: "model",
        message: "The on-device model did not answer in time."
    )

    /// The diagnostic for a message in a language the model cannot read. It shares the failure
    /// code; the field tells the app to explain the language rather than a generic failure.
    private static let unsupportedLanguageDiagnostic = ParseDiagnostic(
        code: .modelFailed,
        field: "language",
        message: "The on-device model cannot read this message's language."
    )

    /// The diagnostic for a generation that failed for any other reason.
    private static let failedDiagnostic = ParseDiagnostic(
        code: .modelFailed,
        field: "model",
        message: "The on-device model could not read this message."
    )

    private static let unavailableMessage = "The on-device model is not available on this device."

    private static func trimmed(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
