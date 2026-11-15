import SwiftUI
import UniformTypeIdentifiers

/// The system folder picker the backup folder is chosen with, such as `iCloud Drive/Zentri Backups`.
///
/// Folders only, one at a time. The picked URL is security-scoped; the folder service turns it into
/// a bookmark straight away.
struct BackupFolderPicker: ViewModifier {
    @Binding var isPresented: Bool
    let onPick: @MainActor (Result<URL, any Error>) -> Void

    func body(content: Content) -> some View {
        content
            .fileImporter(isPresented: $isPresented, allowedContentTypes: [.folder], onCompletion: onPick)
    }
}

extension View {
    /// Presents the backup folder picker while `isPresented` is true.
    func backupFolderPicker(
        isPresented: Binding<Bool>,
        onPick: @escaping @MainActor (Result<URL, any Error>) -> Void
    ) -> some View {
        modifier(BackupFolderPicker(isPresented: isPresented, onPick: onPick))
    }
}
