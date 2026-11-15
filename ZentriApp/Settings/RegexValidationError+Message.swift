import Foundation
import ZentriCore

extension RegexValidationError {
    /// What the rule editor says under the pattern field.
    ///
    /// A syntax error shows the regex compiler's own detail beneath this message, because only it
    /// names the position of the problem.
    var message: LocalizedStringResource {
        switch self {
        case .emptyPattern: "Enter a pattern."
        case .invalidSyntax: "This isn't a valid regular expression."
        case .missingAmountGroup: "Add an amount group, such as (?<amount>[0-9.,]+)."
        }
    }

    /// The regex compiler's detail for a syntax error, shown verbatim.
    var compilerDetail: String? {
        if case .invalidSyntax(let detail) = self { return detail }
        return nil
    }
}
