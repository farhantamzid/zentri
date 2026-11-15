import SwiftUI

/// Settings › Backup: the plain-JSON warning, the automatic iCloud Drive backup, and manual export
/// and import.
///
/// This view only wires the app's state into the models; ``BackupSettingsForm`` owns them.
struct BackupSettingsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        BackupSettingsForm(
            settingsModel: BackupSettingsModel(
                folder: appState.backupFolder,
                settingsStore: appState.settingsStore,
                scheduler: appState.backupScheduler,
                makeExport: appState.makeBackupDocument,
                onFolderChosen: appState.backupScheduler.schedule
            ),
            restoreModel: BackupRestoreModel.make(for: appState)
        )
        .background { Theme.canvas.ignoresSafeArea() }
        .navigationTitle("Backup")
    }
}

