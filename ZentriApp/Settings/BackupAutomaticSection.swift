import SwiftUI
import ZentriCore

/// The automatic iCloud Drive backup: the folder, the last backup, and what went wrong if anything
/// did.
struct BackupAutomaticSection: View {
    let folderState: BackupFolderState
    let lastBackupAt: Date?
    let status: BackupStatus
    let isAwaitingConfirmation: Bool
    let onChooseFolder: () -> Void
    let onConfirmFolder: () -> Void
    let onForgetFolder: () -> Void

    var body: some View {
        Section {
            LabeledContent("Folder") {
                BackupFolderStateText(state: folderState)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("backup.folder")

            LabeledContent("Last backup") {
                if let lastBackupAt {
                    Text(lastBackupAt, format: .dateTime.day().month().year().hour().minute())
                } else {
                    Text("Never")
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("backup.lastBackup")

            if let error = failure {
                Label {
                    Text(error.message)
                        .foregroundStyle(Theme.ink)
                } icon: {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(Theme.spending)
                }
                .accessibilityIdentifier("backup.failure")
            }

            if isAwaitingConfirmation {
                BackupHeldFolderNotice(onConfirm: onConfirmFolder)
            }

            Button(chooseTitle, systemImage: "folder.badge.plus", action: onChooseFolder)
                .accessibilityIdentifier("backup.chooseFolder")

            SettingsLink(destination: .backupRestore)

            if hasFolder {
                Button("Stop Automatic Backups", systemImage: "xmark.circle", role: .destructive, action: onForgetFolder)
                    .accessibilityIdentifier("backup.forgetFolder")
            }
        } header: {
            Text("Automatic backup")
        } footer: {
            Text("Zentri saves a snapshot to this folder a few seconds after your data changes and when you leave the app, keeping the latest 10. Choose a folder in iCloud Drive so the backups survive deleting the app.")
        }
    }

    /// Whether a folder is chosen, even one that needs choosing again.
    private var hasFolder: Bool {
        switch folderState {
        case .chosen, .failed: true
        case .loading, .none: false
        }
    }

    /// Why the folder cannot be used, or why the last backup failed.
    private var failure: BackupFolderError? {
        if case .failed(let error) = folderState { return error }
        if case .failed(let error) = status { return error }
        return nil
    }

    private var chooseTitle: LocalizedStringResource {
        hasFolder ? "Choose a different folder" : "Choose iCloud Drive folder"
    }
}
