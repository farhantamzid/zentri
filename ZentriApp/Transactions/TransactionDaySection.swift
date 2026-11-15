import Foundation

/// One day of the list: its transactions, newest first.
struct TransactionDaySection: Sendable, Equatable, Identifiable {
    /// The day's first instant, which is also the section's stable identity.
    let day: Date
    /// The day's transactions, newest first.
    let items: [TransactionListItem]

    var id: Date { day }
}
