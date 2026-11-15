import SwiftUI
import ZentriCore

/// One problem a parse ran into, with the rule it came from when there is one.
struct ParseDiagnosticRow: View {
    let diagnostic: ParseDiagnostic
    let ruleName: String?

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(diagnostic.localizedMessage)
                    .foregroundStyle(Theme.ink)
                if let ruleName {
                    Text("Rule: \(ruleName)")
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryInk)
                }
            }
        } icon: {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(Theme.spending)
        }
        .accessibilityElement(children: .combine)
    }
}
