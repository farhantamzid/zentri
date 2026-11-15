import Foundation

extension WidgetSnapshot {
    /// Whether two snapshots would draw the same widgets: every field but ``generatedAt`` matches.
    ///
    /// The app rewrites the snapshot after every ingestion, including messages that change nothing,
    /// such as a one-time password. Only a snapshot that shows something different is worth a
    /// WidgetKit timeline reload, which the system budgets.
    public func showsSameContent(as other: WidgetSnapshot) -> Bool {
        var other = other
        other.generatedAt = generatedAt
        return self == other
    }
}
