import SwiftUI
import ZentriCore

/// Why the pattern cannot be saved, under the pattern field, with the compiler's detail for a
/// syntax error.
struct RulePatternErrorView: View {
    let error: RegexValidationError

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(error.message)
                    .foregroundStyle(Theme.ink)
                if let detail = error.compilerDetail {
                    Text(verbatim: detail)
                        .font(.subheadline.monospaced())
                        .foregroundStyle(Theme.secondaryInk)
                }
            }
        } icon: {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(Theme.spending)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("ruleEditor.patternError")
    }
}
