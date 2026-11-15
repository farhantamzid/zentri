import SwiftUI
import UniformTypeIdentifiers

/// An encoded backup, as the export and import pickers hand it over.
struct BackupFileDocument: FileDocument {
    /// A manual export (`.zentri.json`) or an automatic snapshot (`.json`) can be opened.
    static let readableContentTypes: [UTType] = [.zentriBackup, .json]
    static let writableContentTypes: [UTType] = [.zentriBackup]

    /// The backup's JSON.
    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
