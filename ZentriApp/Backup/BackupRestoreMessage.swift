import Foundation
import ZentriCore

/// What a restore screen says when opening or restoring a backup fails.
enum BackupRestoreMessage {
    static func message(for error: any Error) -> LocalizedStringResource {
        switch error {
        case let error as BackupError:
            error.message
        case let error as BackupFolderError:
            error.message
        case BackupRestoreError.settingsNotSaved:
            "Your data was restored, but its currency and display settings couldn't be saved, so the previous ones are still in use. Restore the backup again to retry."
        default:
            "Zentri couldn't restore the backup. Your data is unchanged."
        }
    }
}
