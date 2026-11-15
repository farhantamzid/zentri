/// Why ``ParsingRuleMutationService`` refused a change before writing anything.
public enum ParsingRuleMutationError: Error, Equatable, Sendable {
    /// The name was blank.
    case missingName
    /// The account the rule names does not exist.
    case missingAccount
    /// The pattern cannot be saved as a rule.
    case invalidPattern(RegexValidationError)
}
