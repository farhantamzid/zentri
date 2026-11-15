/// What a parse result means for the archive.
enum ParseDisposition {
    /// A validated transaction.
    case transaction(TransactionDraft)
    /// The message is not a transaction.
    case notTransaction
    /// The message could not be read; the diagnostics explain why.
    case failed([ParseDiagnostic])
    /// The caller cancelled the work, so the message must stay retryable.
    case cancelled([ParseDiagnostic])

    /// Classifies a parse result, folding cancellation in.
    ///
    /// Cancellation is checked here rather than trusted to the engines: the hybrid engine collapses a
    /// cancelled rule parse into `.notTransaction` when the model finds nothing, and every
    /// diagnostic is inspected so a cancellation reported after another failure is still caught.
    init(classifying result: ParseResult) {
        if Task.isCancelled {
            if case .failure(let diagnostics) = result {
                self = .cancelled(diagnostics)
            } else {
                self = .cancelled([])
            }
            return
        }
        switch result {
        case .transaction(let draft):
            self = .transaction(draft)
        case .notTransaction:
            self = .notTransaction
        case .failure(let diagnostics):
            self = diagnostics.contains { $0.code == .cancelled }
                ? .cancelled(diagnostics)
                : .failed(diagnostics)
        }
    }
}
