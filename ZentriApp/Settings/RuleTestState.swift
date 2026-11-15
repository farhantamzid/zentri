import ZentriCore

/// Where the tester's last run got.
enum RuleTestState: Sendable, Equatable {
    /// Nothing has been tested yet.
    case idle
    /// A test is running.
    case running
    /// The last test's answers.
    case finished(RuleComparison)
}
