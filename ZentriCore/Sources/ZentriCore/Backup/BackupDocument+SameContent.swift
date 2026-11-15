import Foundation

extension BackupDocument {
    /// Whether two documents hold the same data, ignoring when and by which version each was written.
    ///
    /// `exportedAt`, `appVersion`, and `settings.lastBackupAt` change on every backup even when nothing
    /// else has, so they are left out; everything else, settings included, must match. The automatic
    /// backup uses this to skip a snapshot that would repeat the newest one.
    public func hasSameContent(as other: BackupDocument) -> Bool {
        normalized == other.normalized
    }

    private var normalized: BackupDocument {
        var copy = self
        copy.exportedAt = ""
        copy.appVersion = ""
        copy.settings.lastBackupAt = nil
        return copy
    }
}
