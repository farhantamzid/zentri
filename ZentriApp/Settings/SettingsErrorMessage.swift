import Foundation
import ZentriCore

/// What a Settings screen tells the person when a change fails.
enum SettingsErrorMessage {
    /// The service's reason when it refused the change, or a general retry message when the store
    /// failed to save it.
    static func message(for error: any Error) -> LocalizedStringResource {
        switch error {
        case let error as AccountMutationError: error.message
        case let error as CategoryMutationError: error.message
        case let error as ParsingRuleMutationError: error.message
        case CategorizationRulesModelError.missingCategory: "That category no longer exists. Choose another."
        default: "Zentri couldn't save your changes. Try again."
        }
    }
}
