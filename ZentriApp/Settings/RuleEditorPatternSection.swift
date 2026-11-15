import SwiftUI

/// The pattern in a monospaced field with its inline error, the matching options, and the date
/// format.
struct RuleEditorPatternSection: View {
    @Bindable var model: RuleEditorModel

    var body: some View {
        Section {
            TextField("Pattern", text: $model.pattern, prompt: Text(verbatim: "RM(?<amount>[\\d.,]+)"), axis: .vertical)
                .lineLimit(2...)
                .font(.body.monospaced())
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .accessibilityIdentifier("ruleEditor.pattern")

            if let error = model.patternError {
                RulePatternErrorView(error: error)
            }

            Toggle("Ignore case", isOn: $model.isCaseInsensitive)
            Toggle("Dot matches new lines", isOn: $model.dotMatchesNewlines)

            TextField("Date format", text: $model.dateFormat, prompt: Text(verbatim: "dd/MM/yy"))
                .font(.body.monospaced())
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .accessibilityIdentifier("ruleEditor.dateFormat")
        } header: {
            Text("Pattern")
        } footer: {
            Text("A Swift regular expression with named groups. The date format is optional: without one, common formats are tried, then the time the message arrived.")
        }
    }
}
