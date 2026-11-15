import Foundation

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

/// Checks a rule pattern before it is saved or previewed.
///
/// Compiling a pattern is cheap and bounded by its length, so it is safe to run on every
/// keystroke; *matching* a pattern is not, which is why nothing here runs a match.
///
/// Saving a rule is the guard against a broken enabled pattern: the rule engine reports a
/// pattern that does not compile as a failure for every message it sees, including one-time
/// passwords, so a broken pattern must never reach the store as an enabled rule.
public enum RegexValidator {
    /// The capture group every rule must have.
    public static let amountGroupName = "amount"

    /// Compiles `pattern`, reporting an empty pattern or a syntax error.
    ///
    /// A pattern without an `amount` group still compiles here; use ``hasAmountGroup(_:)`` or
    /// ``validateRule(pattern:)`` to check that too.
    public static func validate(pattern: String) -> Result<Regex<AnyRegexOutput>, RegexValidationError> {
        guard !pattern.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .failure(.emptyPattern)
        }
        do {
            return .success(try Regex(pattern))
        } catch {
            return .failure(.invalidSyntax(String(describing: error)))
        }
    }

    /// Whether a compiled pattern has a capture group named exactly `amount`.
    public static func hasAmountGroup(_ regex: Regex<AnyRegexOutput>) -> Bool {
        regex.contains(captureNamed: amountGroupName)
    }

    /// The reason `pattern` cannot be saved as a rule, or `nil` when it can.
    public static func validateRule(pattern: String) -> RegexValidationError? {
        switch validate(pattern: pattern) {
        case .failure(let error):
            error
        case .success(let regex):
            hasAmountGroup(regex) ? nil : .missingAmountGroup
        }
    }
}
