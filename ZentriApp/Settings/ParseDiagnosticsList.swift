import SwiftUI
import ZentriCore

/// Why a parse produced no transaction, one localized line per problem.
struct ParseDiagnosticsList: View {
    let diagnostics: [ParseDiagnostic]
    /// The rule names to attribute a diagnostic to, when it came from a rule.
    let ruleNames: [UUID: String]

    var body: some View {
        // Diagnostics have no identity of their own, and the list is only ever replaced whole by a
        // new parse, never edited in place, so its positions are stable for its lifetime.
        ForEach(diagnostics.indices, id: \.self) { index in
            ParseDiagnosticRow(diagnostic: diagnostics[index], ruleName: ruleName(for: diagnostics[index]))
        }
    }

    private func ruleName(for diagnostic: ParseDiagnostic) -> String? {
        diagnostic.ruleID.flatMap { ruleNames[$0] }
    }
}
