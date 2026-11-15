import SwiftUI

/// The restore browser: the backup folder's snapshots, plus a backup file picked anywhere.
///
/// Reached from Settings › Backup and from the settings-recovery screen, where there are no settings
/// and the backup's are what a restore brings back. This view only wires the app's state into the
/// model; ``BackupRestoreList`` owns it.
struct BackupRestoreView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        BackupRestoreList(model: BackupRestoreModel.make(for: appState))
            .background { Theme.canvas.ignoresSafeArea() }
            .navigationTitle("Restore Backup")
    }
}
