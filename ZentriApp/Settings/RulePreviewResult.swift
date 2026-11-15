import SwiftUI
import ZentriCore

/// What the rule made of the sample: the captured groups, then the extracted fields or the reasons
/// there are none.
struct RulePreviewResult: View {
    let preview: RulePreview

    var body: some View {
        if preview.captures.isEmpty {
            Text("The pattern doesn't match the sample.")
                .foregroundStyle(Theme.secondaryInk)
                .accessibilityIdentifier("ruleEditor.noMatch")
        } else {
            ForEach(preview.captures) { capture in
                LabeledContent {
                    Text(verbatim: capture.value)
                        .font(.body.monospaced())
                } label: {
                    Text(verbatim: capture.name)
                        .font(.body.monospaced())
                }
            }
        }

        switch preview.result {
        case .transaction(let draft):
            ParsedDraftFields(draft: draft, identifierPrefix: "ruleEditor")
        case .notTransaction:
            EmptyView()
        case .failure(let diagnostics):
            ParseDiagnosticsList(diagnostics: diagnostics, ruleNames: [:])
        }
    }
}
