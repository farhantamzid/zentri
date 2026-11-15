import Foundation
import ZentriCore

extension CategoryMutationError {
    /// What a category or rule sheet tells the person when a change is refused.
    var message: LocalizedStringResource {
        switch self {
        case .missingName: "Enter a name for the category."
        case .duplicateName: "Another category already has that name."
        case .fallbackCategoryProtected: "Other collects everything no rule matches, so it can't be renamed or deleted."
        case .missingFallbackCategory: "Zentri couldn't find the Other category to move these transactions to."
        case .missingKeyword: "Enter a keyword."
        case .duplicateKeyword: "Another rule already uses that keyword."
        }
    }
}
