import Foundation
import ZentriCore

extension ParseStatus {
    /// How the inbox names a message's status.
    var displayName: LocalizedStringResource {
        switch self {
        case .processing: "Pending"
        case .parsed: "Parsed"
        case .ignored: "Ignored"
        case .failed: "Failed"
        case .duplicate: "Duplicate"
        }
    }

    /// The SF Symbol shown beside the status, so color is never the only signal.
    var systemImage: String {
        switch self {
        case .processing: "clock"
        case .parsed: "checkmark.circle"
        case .ignored: "minus.circle"
        case .failed: "exclamationmark.triangle"
        case .duplicate: "square.on.square"
        }
    }
}
