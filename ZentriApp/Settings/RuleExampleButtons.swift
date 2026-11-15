import SwiftUI

/// "Copy Example" and "Use Example" for the cheat sheet's example pattern.
struct RuleExampleButtons: View {
    let onCopy: @MainActor () -> Void
    let onUse: @MainActor () -> Void

    var body: some View {
        Button(action: onCopy) {
            Label("Copy Example", systemImage: "doc.on.doc")
                .frame(minHeight: Theme.Layout.minimumTapTarget)
                .contentShape(.rect)
        }
        .buttonStyle(.bordered)
        .accessibilityIdentifier("ruleEditor.copyExample")

        Button(action: onUse) {
            Label("Use Example", systemImage: "text.insert")
                .frame(minHeight: Theme.Layout.minimumTapTarget)
                .contentShape(.rect)
        }
        .buttonStyle(.bordered)
        .accessibilityIdentifier("ruleEditor.useExample")
    }
}
