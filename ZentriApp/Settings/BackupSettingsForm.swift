import SwiftUI
import ZentriCore

/// The Backup form. It owns the screen's two models: the folder and export, and the file import.
struct BackupSettingsForm: View {
    @State private var settingsModel: BackupSettingsModel
    @State private var restoreModel: BackupRestoreModel
    @State private var isChoosingFolder = false
    @State private var isImporting = false
    @State private var isConfirmingForget = false

    init(settingsModel: BackupSettingsModel, restoreModel: BackupRestoreModel) {
        _settingsModel = State(initialValue: settingsModel)
        _restoreModel = State(initialValue: restoreModel)
    }

    var body: some View {
        Form {
            BackupWarningSection()

            BackupAutomaticSection(
                folderState: settingsModel.folderState,
                lastBackupAt: settingsModel.lastBackupAt,
                status: settingsModel.status,
                onChooseFolder: chooseFolder,
                onForgetFolder: confirmForget
            )
            .confirmationDialog(
                "Stop automatic backups?",
                isPresented: $isConfirmingForget,
                titleVisibility: .visible
            ) {
                Button("Stop Automatic Backups", role: .destructive, action: forgetFolder)
            } message: {
                Text("Zentri stops writing to this folder. The backups already in it are kept.")
            }

            Section {
                Button("Export Backup", systemImage: "square.and.arrow.up", action: export)
                    .accessibilityIdentifier("backup.export")
                Button("Import Backup File", systemImage: "square.and.arrow.down", action: startImport)
                    .accessibilityIdentifier("backup.import")
                    .disabled(restoreModel.isWorking)
            } header: {
                Text("Manual backup")
            } footer: {
                Text("Export saves one file wherever you choose. Importing shows what the file holds before anything changes.")
            }
        }
        .scrollContentBackground(.hidden)
        .task {
            await settingsModel.refreshFolder()
        }
        .backupFolderPicker(isPresented: $isChoosingFolder, onPick: folderPicked)
        .fileExporter(
            isPresented: $settingsModel.isExporting,
            document: settingsModel.exportFile,
            contentType: .zentriBackup,
            defaultFilename: settingsModel.exportFilename,
            onCompletion: settingsModel.finishExport
        )
        .backupRestoreFlow(model: restoreModel, isImporting: $isImporting)
        .alert("Backup", item: $settingsModel.failureMessage) { _ in
        } message: { message in
            Text(message)
        }
        .sensoryFeedback(.success, trigger: settingsModel.exportCount)
    }

    private func chooseFolder() {
        isChoosingFolder = true
    }

    private func folderPicked(_ result: Result<URL, any Error>) {
        Task { await settingsModel.chooseFolder(result) }
    }

    private func confirmForget() {
        isConfirmingForget = true
    }

    private func forgetFolder() {
        Task { await settingsModel.forgetFolder() }
    }

    private func export() {
        Task { await settingsModel.prepareExport() }
    }

    private func startImport() {
        isImporting = true
    }
}
