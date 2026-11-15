import SwiftUI
import ZentriCore

/// Everything after a backup is chosen, shared by the Backup screen and the restore browser: the
/// file picker, the summary and confirmation, the failure alert, and the success message.
struct BackupRestoreFlow: ViewModifier {
    @Bindable var model: BackupRestoreModel
    @Binding var isImporting: Bool

    func body(content: Content) -> some View {
        content
            .fileImporter(
                isPresented: $isImporting,
                allowedContentTypes: BackupFileDocument.readableContentTypes,
                onCompletion: filePicked
            )
            .sheet(item: $model.candidate) { candidate in
                BackupRestoreConfirmation(
                    candidate: candidate,
                    modes: model.availableModes,
                    onRestore: restore
                )
            }
            .alert("Couldn't restore", item: $model.failureMessage) { _ in
            } message: { message in
                Text(message)
            }
            .alert("Backup restored", item: $model.completedSummary) { _ in
            } message: { summary in
                BackupRestoreSummaryText(summary: summary)
            }
            .sensoryFeedback(.success, trigger: model.completedSummary) { _, summary in
                summary != nil
            }
    }

    private func filePicked(_ result: Result<URL, any Error>) {
        Task { await model.openFile(result) }
    }

    private func restore(_ candidate: BackupRestoreCandidate, mode: ImportMode) {
        Task { await model.restore(candidate, mode: mode) }
    }
}

extension View {
    /// Adds the restore flow for `model`, with the file picker shown while `isImporting` is true.
    func backupRestoreFlow(model: BackupRestoreModel, isImporting: Binding<Bool>) -> some View {
        modifier(BackupRestoreFlow(model: model, isImporting: isImporting))
    }
}
