import SwiftUI
import ZentriCore

/// What the rules made of the sample: the winning rule and its fields, the reasons nothing
/// matched, and any other rules that matched too.
struct RuleTesterRulesSection: View {
    let result: ParseResult
    let milliseconds: Double?
    let matchingRuleIDs: [UUID]
    let model: RuleTesterModel

    var body: some View {
        Section {
            switch result {
            case .transaction(let draft):
                LabeledContent("Matched rule") {
                    Text(model.ruleName(for: draft.matchedRuleID) ?? "")
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("tester.rules.matchedRule")
                ParsedDraftFields(draft: draft, identifierPrefix: "tester.rules")
            case .notTransaction:
                Text("No rule matched this message.")
                    .foregroundStyle(Theme.secondaryInk)
                    .accessibilityIdentifier("tester.rules.noMatch")
            case .failure(let diagnostics):
                ParseDiagnosticsList(diagnostics: diagnostics, ruleNames: model.ruleNames)
            }

            if matchingRuleIDs.count > 1 {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Also matched")
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryInk)
                    ForEach(matchingRuleIDs, id: \.self) { id in
                        Text(model.ruleName(for: id) ?? "")
                            .foregroundStyle(Theme.ink)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        } header: {
            RuleTesterSideHeader(title: "Rules", milliseconds: milliseconds)
        }
    }
}
