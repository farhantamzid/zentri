import SwiftUI
import ZentriCore

/// The restore browser's list. It owns the model, reads the folder when it appears, and offers a
/// file picked anywhere when the folder has nothing to restore.
struct BackupRestoreList: View {
    @State private var model: BackupRestoreModel
    @State private var isImporting = false
    @State private var isChoosingFolder = false

    init(model: BackupRestoreModel) {
        _model = State(initialValue: model)
    }

    var body: some View {
        Form {
            BackupWarningSection()

            Section {
                BackupSnapshotsStateView(
                    state: model.snapshotsState,
                    onOpen: open,
                    onChooseFolder: chooseFolder,
                    onRetry: reload
                )
            } header: {
                Text("From your backup folder")
            }

            Section {
                Button("Choose a Backup File", systemImage: "doc.badge.arrow.up", action: startImport)
                    .accessibilityIdentifier("backup.restore.chooseFile")
            } footer: {
                Text("Pick a backup you exported, or a snapshot from any folder.")
            }
        }
        .scrollContentBackground(.hidden)
        .disabled(model.isWorking)
        .overlay {
            if model.isWorking {
                ProgressView()
            }
        }
        .task {
            await model.loadSnapshots()
        }
        .refreshable {
            await model.loadSnapshots()
        }
        .backupFolderPicker(isPresented: $isChoosingFolder, onPick: folderPicked)
        .backupRestoreFlow(model: model, isImporting: $isImporting)
    }

    private func open(_ snapshot: SnapshotInfo) {
        Task { await model.open(snapshot) }
    }

    private func chooseFolder() {
        isChoosingFolder = true
    }

    private func folderPicked(_ result: Result<URL, any Error>) {
        Task { await model.chooseFolder(result) }
    }

    private func reload() {
        Task { await model.loadSnapshots() }
    }

    private func startImport() {
        isImporting = true
    }
}
