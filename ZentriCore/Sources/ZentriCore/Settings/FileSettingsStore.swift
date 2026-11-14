import Foundation

/// Reads and writes the settings document that the app and widget share.
public protocol SettingsRepository: Sendable {
    /// Returns the stored settings, or `nil` when nothing has been saved yet.
    func load() throws -> AppSettings?
    /// Replaces the stored settings with `settings`.
    func save(_ settings: AppSettings) throws
}

/// Errors raised while reading settings.
public enum SettingsError: Error, Equatable, Sendable {
    /// The stored document exists but is not decodable settings.
    case corrupt
}

/// A ``SettingsRepository`` that stores settings as a JSON file.
public struct FileSettingsStore: SettingsRepository {
    private let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public func load() throws -> AppSettings? {
        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return nil
        }

        do {
            return try JSONDecoder().decode(AppSettings.self, from: data)
        } catch {
            throw SettingsError.corrupt
        }
    }

    public func save(_ settings: AppSettings) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(settings)
        try data.write(to: fileURL, options: .atomic)
    }
}
