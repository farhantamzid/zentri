import ZentriCore

/// What "Reprocess Failures" achieved, for the alert that follows it.
struct ReprocessSummary: Sendable, Equatable, Identifiable {
    /// How many failed messages were tried.
    let attempted: Int
    /// How many became transactions.
    let parsed: Int
    /// How many still failed.
    let stillFailed: Int

    var id: String { "\(attempted)-\(parsed)-\(stillFailed)" }

    init(outcomes: [IngestionOutcome]) {
        attempted = outcomes.count
        parsed = outcomes.count(where: \.isTransaction)
        stillFailed = outcomes.count { outcome in
            if case .failed = outcome { return true }
            return false
        }
    }
}
