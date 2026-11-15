import Foundation
import ZentriCore

extension BackupFolderError {
    /// What the Backup screens say about this failure.
    var message: LocalizedStringResource {
        switch self {
        case .noFolderSelected:
            "No backup folder is chosen. Choose an iCloud Drive folder to back up automatically."
        case .permissionDenied:
            "Zentri can no longer use the backup folder. Choose it again."
        case .insufficientSpace:
            "There isn't enough space to save the backup. Your previous backup is unchanged."
        case .unreadable:
            "Zentri couldn't read the backup folder. Check that iCloud Drive is available, then try again."
        case .writeFailed:
            "Zentri couldn't save the backup. Check that iCloud Drive is available. Your previous backup is unchanged."
        }
    }
}
