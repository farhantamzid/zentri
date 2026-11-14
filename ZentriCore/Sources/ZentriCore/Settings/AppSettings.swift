import Foundation

/// The user's app-wide preferences, shared with the widget extension through settings storage.
public struct AppSettings: Codable, Equatable, Sendable {
    /// The display currency. Changing it never converts stored amounts.
    public var currencyCode: String
    /// How amounts are grouped for display.
    public var numberGrouping: NumberGrouping
    /// The parser engine used for new raw messages.
    public var parserMode: ParserMode
    /// Whether the app requires Face ID to unlock.
    public var faceIDEnabled: Bool
    /// Whether backups are written to the user's iCloud folder.
    public var iCloudBackupEnabled: Bool
    /// When the last backup completed, if one has.
    public var lastBackupAt: Date?
    /// The settings schema version, used when migrating stored documents.
    public var schemaVersion: Int

    public init(
        currencyCode: String = "USD",
        numberGrouping: NumberGrouping = .western,
        parserMode: ParserMode = .hybrid,
        faceIDEnabled: Bool = false,
        iCloudBackupEnabled: Bool = false,
        lastBackupAt: Date? = nil,
        schemaVersion: Int = 1
    ) {
        self.currencyCode = currencyCode
        self.numberGrouping = numberGrouping
        self.parserMode = parserMode
        self.faceIDEnabled = faceIDEnabled
        self.iCloudBackupEnabled = iCloudBackupEnabled
        self.lastBackupAt = lastBackupAt
        self.schemaVersion = schemaVersion
    }

    /// The settings a fresh install starts with.
    public static let defaultValue = AppSettings()
}
