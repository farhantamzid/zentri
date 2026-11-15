import Foundation
import ZentriCore

/// A decoded, validated backup waiting for the person to choose how to restore it.
///
/// The summary is what the confirmation shows before anything changes: what the file holds and
/// when it was made.
struct BackupRestoreCandidate: Identifiable, Equatable {
    let id = UUID()
    let document: BackupDocument

    /// When the backup was made.
    var exportDate: Date? { document.exportDate }
    /// The backup's format version.
    var schemaVersion: Int { document.schemaVersion }
    /// How many accounts it holds.
    var accountCount: Int { document.accounts.count }
    /// How many transactions it holds.
    var transactionCount: Int { document.transactions.count }
    /// Parsing rules and keyword rules together.
    var ruleCount: Int { document.parsingRules.count + document.categorizationRules.count }
    /// The first and last transaction dates.
    var dateRange: ClosedRange<Date>? { document.transactionDateRange }
}
