import Foundation
import ZentriCore

extension ParsingRuleMutationError {
    /// What the rule screens tell the person when a change is refused.
    var message: LocalizedStringResource {
        switch self {
        case .missingName: "Enter a name for the rule."
        case .missingAccount: "That account no longer exists. Choose another."
        case .invalidPattern(let error): error.message
        }
    }
}
