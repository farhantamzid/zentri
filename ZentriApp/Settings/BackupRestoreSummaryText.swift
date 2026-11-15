import SwiftUI
import ZentriCore

/// What a finished restore did.
struct BackupRestoreSummaryText: View {
    let summary: ImportSummary

    var body: some View {
        switch summary.mode {
        case .replace:
            Text("Your data now matches the backup: ^[\(summary.created.accounts) account](inflect: true) and ^[\(summary.created.transactions) transaction](inflect: true).")
        case .merge:
            Text("Added ^[\(summary.created.total) record](inflect: true) from the backup. \(summary.skipped.total) already here were left as they are.")
        }
    }
}
