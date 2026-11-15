import SwiftUI

/// The warning every backup screen carries: the files are readable by anyone who has them.
struct BackupWarningSection: View {
    var body: some View {
        Section {
            Label {
                Text("Backups are plain JSON files. They are not encrypted and include the full text of your bank SMS messages, so keep them somewhere private.")
                    .foregroundStyle(Theme.ink)
            } icon: {
                Image(systemName: "exclamationmark.lock")
                    .foregroundStyle(Theme.spending)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("backup.plainJSONWarning")
        }
    }
}
