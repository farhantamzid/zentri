/// The diagnostics ingestion and reprocessing report about accounts, storage, and cancellation.
///
/// ``ParseDiagnostic/Code`` describes parsing problems only and has no account or storage case, so
/// these are reported as a missing field named `account` or `storage`: something the outcome needs
/// is absent. The app tells them apart by that field.
enum IngestionDiagnostics {
    /// The message for a capture that names more than one possible account.
    static let chooseAccount = ParseDiagnostic(
        code: .missingField,
        field: "account",
        message: "Choose an account in the Shortcut."
    )

    /// The message for a capture with no account to fall back on.
    static let addAccount = ParseDiagnostic(
        code: .missingField,
        field: "account",
        message: "Add an account in Zentri before capturing messages."
    )

    /// The message for a retry or reprocess that still cannot identify an account.
    static let retryAccount = ParseDiagnostic(
        code: .missingField,
        field: "account",
        message: "Choose an account for this message."
    )

    /// The message for a write that could not be saved.
    static let storage = ParseDiagnostic(
        code: .missingField,
        field: "storage",
        message: "The message could not be saved. Try again."
    )

    /// The diagnostic reported when a parse was cancelled without one of its own.
    static let cancelled = ParseDiagnostic(
        code: .cancelled,
        message: "Parsing was cancelled."
    )

    /// A user-facing error description built from diagnostics; it never contains message text.
    static func errorDescription(of diagnostics: [ParseDiagnostic]) -> String? {
        let description = diagnostics.map(\.message).joined(separator: " ")
        return description.isEmpty ? nil : description
    }
}
