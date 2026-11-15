import Foundation
import ZentriCore

extension Direction {
    /// How the list and editor name the direction.
    var displayName: LocalizedStringResource {
        switch self {
        case .debit: "Spent"
        case .credit: "Received"
        }
    }
}

extension ParseEngine {
    /// How the detail and filters name the source of a transaction.
    var displayName: LocalizedStringResource {
        switch self {
        case .rules: "Bank rule"
        case .foundationModels: "Apple Intelligence"
        case .manual: "Manual"
        }
    }
}

extension CategorySource {
    /// How the detail explains where the category came from.
    var displayName: LocalizedStringResource {
        switch self {
        case .rule: "Keyword rule"
        case .ai: "Apple Intelligence"
        case .manual: "You chose it"
        case .default: "Default"
        }
    }
}

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
