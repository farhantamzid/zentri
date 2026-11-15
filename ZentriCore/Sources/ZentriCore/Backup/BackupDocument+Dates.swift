import Foundation

extension BackupDocument {
    /// When the backup was made, or `nil` if the stored text is not a date (a validated document
    /// always has one).
    public var exportDate: Date? {
        try? BackupCodec.date(from: exportedAt, field: "exportedAt")
    }

    /// The earliest and latest transaction dates, for the restore summary; `nil` without transactions.
    public var transactionDateRange: ClosedRange<Date>? {
        let dates = transactions.compactMap { try? BackupCodec.date(from: $0.occurredAt, field: "occurredAt") }
        guard let earliest = dates.min(), let latest = dates.max() else { return nil }
        return earliest...latest
    }
}
