/// Why ``CategoryMutationService`` refused a change before writing anything.
public enum CategoryMutationError: Error, Equatable, Sendable {
    /// The category's name was blank.
    case missingName
    /// Another category already has this name, ignoring case. Categorization, suggestions, and the
    /// widgets resolve categories by name, so names must stay unique.
    case duplicateName
    /// The change would rename or delete the fallback category,
    /// ``CategorizationService/fallbackCategoryName``, which categorization, the Overview, the
    /// widgets, and the Transactions filter all resolve by name, and which a deleted category's
    /// transactions move to.
    case fallbackCategoryProtected
    /// A delete found no fallback category to move the category's transactions to.
    case missingFallbackCategory
    /// The rule's keyword was blank.
    case missingKeyword
    /// Another rule already matches this keyword, ignoring case.
    case duplicateKeyword
}
