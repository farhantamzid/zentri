import ZentriCore

/// Why a capture was refused before it reached the ingestion pipeline.
///
/// Neither is archived: an unfinished setup has no account to file a message under, and empty text is
/// not a message. They are reported as a missing field so ``CaptureSMSDialog`` can tell them apart by
/// the field, the same way the pipeline's own account and storage diagnostics are told apart.
enum CaptureSMSDiagnostics {
    /// The field of a capture that arrived before onboarding saved any settings.
    static let setupField = "setup"
    /// The field of a capture whose Shortcut passed no text.
    static let textField = "text"

    /// Onboarding has not finished, so there are no settings and no account yet.
    static let setupIncomplete = ParseDiagnostic(
        code: .missingField,
        field: setupField,
        message: "Setup is not finished."
    )

    /// The Shortcut passed empty or whitespace-only text.
    static let emptyText = ParseDiagnostic(
        code: .missingField,
        field: textField,
        message: "The Shortcut passed no message text."
    )
}
