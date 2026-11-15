import SwiftUI
import ZentriCore

/// What Apple Intelligence made of the sample, or that it is unavailable here.
struct RuleTesterModelSection: View {
    let result: ParseResult
    let milliseconds: Double?
    let isAvailable: Bool

    var body: some View {
        Section {
            if isAvailable {
                switch result {
                case .transaction(let draft):
                    ParsedDraftFields(draft: draft, identifierPrefix: "tester.model")
                case .notTransaction:
                    Text("Apple Intelligence says this isn't a transaction.")
                        .foregroundStyle(Theme.secondaryInk)
                case .failure(let diagnostics):
                    ParseDiagnosticsList(diagnostics: diagnostics, ruleNames: [:])
                }
            } else {
                Label {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text("AI unavailable")
                            .foregroundStyle(Theme.ink)
                        Text("Apple Intelligence can't run on this device right now. In hybrid mode, your rules still read every message.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.secondaryInk)
                    }
                } icon: {
                    Image(systemName: "sparkles")
                        .foregroundStyle(Theme.secondaryInk)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("tester.model.status")
            }
        } header: {
            RuleTesterSideHeader(title: "Apple Intelligence", milliseconds: milliseconds)
        }
    }
}
