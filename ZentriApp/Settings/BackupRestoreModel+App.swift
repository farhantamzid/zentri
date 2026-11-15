import ZentriCore

extension BackupRestoreModel {
    /// A restore model over the app's folder, settings, and restore path.
    static func make(for appState: AppState) -> BackupRestoreModel {
        BackupRestoreModel(
            folder: appState.backupFolder,
            canMerge: { [settingsStore = appState.settingsStore] in settingsStore.settings != nil },
            restore: appState.restoreBackup
        )
    }
}
