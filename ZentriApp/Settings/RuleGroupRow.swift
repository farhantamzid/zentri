import SwiftUI

/// One named group in the cheat sheet: its name in code type and what it holds.
struct RuleGroupRow: View {
    let name: String
    let detail: LocalizedStringResource

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(verbatim: name)
                .font(.body.monospaced())
                .foregroundStyle(Theme.ink)
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryInk)
        }
        .accessibilityElement(children: .combine)
    }
}
