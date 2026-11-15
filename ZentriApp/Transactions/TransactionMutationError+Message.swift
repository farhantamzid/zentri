import Foundation
import ZentriCore

extension TransactionMutationError {
    /// What the editor tells the person when a save is refused.
    var message: LocalizedStringResource {
        switch self {
        case .invalidAmount: "Enter an amount greater than zero."
        case .missingAccount: "Choose an account."
        case .missingMerchant: "Enter a merchant."
        case .missingCategory: "That category no longer exists. Choose another."
        }
    }
}
