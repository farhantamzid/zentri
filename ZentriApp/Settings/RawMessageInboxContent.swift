import SwiftUI
import ZentriCore

/// The inbox: the status filter, the messages under it, and the archive-wide actions.
///
/// "Reprocess Failures" and "Clear Archive" are confirmed first. Their dialogs hang off the list
/// rather than the toolbar buttons, because the system can move toolbar buttons into its overflow
/// menu, where an attached dialog never appears.
struct RawMessageInboxContent: View {
    @State private var model: RawMessageInboxModel
    @State private var isConfirmingClear = false
    @State private var isConfirmingReprocess = false
    @State private var isReprocessing = false
    @State private var reprocessSummary: ReprocessSummary?
    @State private var failureMessage: LocalizedStringResource?
    @State private var clearedCount = 0
    private let dataRevision: Int

    init(model: RawMessageInboxModel, dataRevision: Int) {
        _model = State(initialValue: model)
        self.dataRevision = dataRevision
    }

    var body: some View {
        RawMessageInboxStateView(model: model)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Reprocess Failures", systemImage: "arrow.clockwise", action: confirmReprocess)
                        .disabled(model.failedCount == 0 || isReprocessing)
                        .accessibilityIdentifier("inbox.reprocessFailures")
                }
                ToolbarItem(placement: .secondaryAction) {
                    Button("Clear Archive", systemImage: "trash", role: .destructive, action: confirmClear)
                        .disabled(!model.hasMessages)
                        .accessibilityIdentifier("inbox.clearArchive")
                }
            }
            .confirmationDialog("Clear the message archive?", isPresented: $isConfirmingClear, titleVisibility: .visible) {
                Button("Clear Archive", role: .destructive, action: clearArchive)
            } message: {
                Text("Every stored bank message is deleted. Your transactions and balances are kept, but they can no longer be reprocessed.")
            }
            .confirmationDialog("Reprocess failed messages?", isPresented: $isConfirmingReprocess, titleVisibility: .visible) {
                Button("Reprocess Failures", action: reprocessFailures)
            } message: {
                Text("Every failed message is read again with your current rules. Messages that now parse become transactions.")
            }
            .alert("Failures reprocessed", item: $reprocessSummary) { _ in
            } message: { summary in
                Text("Tried \(summary.attempted): \(summary.parsed) became transactions and \(summary.stillFailed) still failed.")
            }
            .alert("Couldn't change the archive", item: $failureMessage) { _ in
            } message: { message in
                Text(message)
            }
            .navigationDestination(for: RawMessageRoute.self) { route in
                RawMessageDetailView(model: model, messageID: route.messageID)
            }
            .onAppear(perform: model.refresh)
            .onChange(of: dataRevision) {
                model.refresh()
            }
            .sensoryFeedback(.warning, trigger: isConfirmingClear) { _, isShowing in isShowing }
            .sensoryFeedback(.success, trigger: clearedCount)
    }

    private func confirmClear() {
        isConfirmingClear = true
    }

    private func confirmReprocess() {
        isConfirmingReprocess = true
    }

    private func clearArchive() {
        do {
            try model.clearArchive()
            clearedCount += 1
        } catch {
            failureMessage = "Zentri couldn't save your changes. Try again."
        }
    }

    private func reprocessFailures() {
        isReprocessing = true
        Task {
            reprocessSummary = await model.reprocessFailures()
            isReprocessing = false
        }
    }
}
