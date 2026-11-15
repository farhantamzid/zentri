/// Why a pattern cannot be saved as a parsing rule.
///
/// The cases carry no user-facing English except the compiler's own detail for a syntax error;
/// the app maps each case to its own localized explanation.
public enum RegexValidationError: Error, Sendable, Equatable {
    /// The pattern is empty or only whitespace.
    case emptyPattern
    /// The pattern is not a valid Swift regex; the associated value is the compiler's detail,
    /// which names the position of the problem.
    case invalidSyntax(String)
    /// The pattern compiles but has no `amount` capture group, so it can never produce a
    /// transaction.
    case missingAmountGroup
}
