import SwiftUI

/// The validation summary shown before a restore: what the backup holds and when it was made.
struct BackupCandidateSummarySection: View {
    let candidate: BackupRestoreCandidate

    var body: some View {
        Section {
            if let exportDate = candidate.exportDate {
                LabeledContent("Made") {
                    Text(exportDate, format: .dateTime.day().month().year().hour().minute())
                }
            }
            LabeledContent("Accounts") {
                Text(candidate.accountCount, format: .number)
            }
            LabeledContent("Transactions") {
                Text(candidate.transactionCount, format: .number)
            }
            LabeledContent("Rules") {
                Text(candidate.ruleCount, format: .number)
            }
            if let dateRange = candidate.dateRange {
                LabeledContent("Transactions from") {
                    Text(dateRange.lowerBound..<dateRange.upperBound, format: .interval.day().month().year())
                }
            }
            LabeledContent("Format version") {
                Text(candidate.schemaVersion, format: .number)
            }
        } header: {
            Text("This backup holds")
        } footer: {
            Text("The file was checked in full. Nothing changes until you choose how to restore it.")
        }
        .accessibilityIdentifier("backup.restore.summary")
    }
}
