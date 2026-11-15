import SwiftUI
import ZentriCore

/// A sample message, the pattern's captures highlighted in it, and what the rule extracted.
struct RuleEditorSampleSection: View {
    @Bindable var model: RuleEditorModel

    var body: some View {
        Section {
            TextField("Sample message", text: $model.sampleText, prompt: Text("Paste a bank message to try the pattern"), axis: .vertical)
                .lineLimit(3...)
                .accessibilityIdentifier("ruleEditor.sample")

            if let highlighted = model.highlightedSample {
                Text(highlighted)
                    .font(.body.monospaced())
                    .foregroundStyle(Theme.ink)
                    .accessibilityLabel(Text("The sample with its captured groups marked"))
            }

            if let preview = model.preview {
                RulePreviewResult(preview: preview)
            }
        } header: {
            Text("Try it")
        } footer: {
            Text("The sample is only used here and is never saved.")
        }
    }
}
