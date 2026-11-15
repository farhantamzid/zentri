import Foundation
import ZentriCore

extension BackupError {
    /// Why a backup cannot be restored, in the person's terms. Nothing has changed when this shows.
    var message: LocalizedStringResource {
        switch self {
        case .unsupportedVersion(let found):
            "This backup was made by a newer version of Zentri (format \(found)). Update Zentri to restore it."
        case .duplicateID:
            "This backup is damaged: two records share the same identity. Nothing was changed."
        case .brokenReference(let field, _):
            "This backup is damaged: \(field) points to a record that isn't in the file. Nothing was changed."
        case .malformedDecimal(let field, _):
            "This backup is damaged: \(field) is not a valid amount. Nothing was changed."
        case .malformedDate(let field, _):
            "This backup is damaged: \(field) is not a valid date. Nothing was changed."
        case .accountWithoutCheckpoint:
            "This backup is damaged: an account has no starting balance. Nothing was changed."
        case .invalidFile:
            "This file isn't a Zentri backup, or it is incomplete. Nothing was changed."
        }
    }
}
