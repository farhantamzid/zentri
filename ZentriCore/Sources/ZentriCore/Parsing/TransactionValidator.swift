import Foundation

/// The diagnostics from a failed validation, in the form `Result` can carry.
///
/// `Result` only accepts an `Error` failure, so the validator wraps its diagnostics here;
/// callers read them back through ``diagnostics``.
public struct TransactionValidationError: Error, Sendable, Equatable {
    /// Every problem found, in a stable order.
    public let diagnostics: [ParseDiagnostic]

    public init(diagnostics: [ParseDiagnostic]) {
        self.diagnostics = diagnostics
    }
}

/// The checks every engine's draft must pass before it can become a transaction.
public enum TransactionValidator {
    /// A message's date may lead the receipt time by at most this much: bank alerts can arrive
    /// a moment after the bank stamps them, but a date further ahead is a bad capture.
    private static let maximumFutureInterval: TimeInterval = 24 * 60 * 60

    /// Validates `draft` against the message's `receivedAt` and returns the normalised draft.
    ///
    /// A missing `occurredAt` becomes `receivedAt`, and the merchant is trimmed and has its
    /// whitespace collapsed. Every problem is reported at once so the rule tester can show
    /// them together.
    public static func validate(
        _ draft: TransactionDraft,
        receivedAt: Date
    ) -> Result<TransactionDraft, TransactionValidationError> {
        var validated = draft
        var diagnostics: [ParseDiagnostic] = []

        if validated.amount <= 0 || validated.amount.isNaN {
            diagnostics.append(ParseDiagnostic(
                code: .amountNotPositive,
                field: "amount",
                message: "The amount must be greater than zero."
            ))
        }

        let occurredAt = validated.occurredAt ?? receivedAt
        validated.occurredAt = occurredAt
        if occurredAt > receivedAt.addingTimeInterval(maximumFutureInterval) {
            diagnostics.append(ParseDiagnostic(
                code: .dateTooFarInFuture,
                field: "date",
                message: "The transaction date is more than 24 hours after the message was received."
            ))
        }

        validated.merchant = collapsedWhitespace(validated.merchant)
        if validated.merchant.isEmpty {
            diagnostics.append(ParseDiagnostic(
                code: .missingMerchant,
                field: "merchant",
                message: "The merchant is missing."
            ))
        }

        return diagnostics.isEmpty
            ? .success(validated)
            : .failure(TransactionValidationError(diagnostics: diagnostics))
    }

    /// Trims and collapses runs of whitespace, including newlines and non-breaking spaces.
    private static func collapsedWhitespace(_ value: String) -> String {
        value.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}
