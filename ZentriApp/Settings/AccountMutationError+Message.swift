import Foundation
import ZentriCore

extension AccountMutationError {
    /// What an account sheet tells the person when a change is refused.
    var message: LocalizedStringResource {
        switch self {
        case .missingName: "Enter a name for the account."
        case .negativeBalance: "Enter a balance of zero or more."
        case .balanceDateInFuture: "Choose a date that isn't in the future."
        case .balanceDateBeforeLatestCheckpoint: "Choose a date after the account's last recorded balance."
        }
    }
}
