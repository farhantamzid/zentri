import SwiftUI

/// The offer to reprocess failed messages after the rules changed, confirmed first.
struct ReprocessFailuresSection: View {
    let failedCount: Int
    let isReprocessing: Bool
    let onReprocess: @MainActor () -> Void

    @State private var isConfirming = false

    var body: some View {
        Section {
            Button(action: confirm) {
                Label {
                    Text("Reprocess ^[\(failedCount) Failed Message](inflect: true)")
                } icon: {
                    Image(systemName: "arrow.clockwise")
                }
                .frame(maxWidth: .infinity, minHeight: Theme.Layout.minimumTapTarget, alignment: .leading)
                .contentShape(.rect)
            }
            .disabled(isReprocessing)
            .accessibilityIdentifier("parsingRules.reprocessFailures")
            .confirmationDialog("Reprocess failed messages?", isPresented: $isConfirming, titleVisibility: .visible) {
                Button("Reprocess Failures", action: onReprocess)
            } message: {
                Text("Every failed message is read again with your current rules. Messages that now parse become transactions.")
            }
        } footer: {
            Text("Your rules changed. Messages that failed before may parse now.")
        }
    }

    private func confirm() {
        isConfirming = true
    }
}
