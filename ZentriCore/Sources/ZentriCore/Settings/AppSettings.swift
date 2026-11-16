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

    private enum CodingKeys: String, CodingKey {
        case currencyCode
        case numberGrouping
        case parserMode
        case faceIDEnabled
        case iCloudBackupEnabled
        case lastBackupAt
        case schemaVersion
    }

    /// Reads a settings document field by field.
    ///
    /// A field that is missing, or holds a value this version cannot read — such as an option added
    /// by a later release — takes its default instead of making the whole document unreadable, and
    /// unknown fields are ignored. A document written by an older or newer version therefore still
    /// loads, and only a document that is not a settings object at all is reported as corrupt.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = AppSettings.defaultValue

        func value<Value: Decodable>(_ key: CodingKeys, default fallback: Value) -> Value {
            ((try? container.decodeIfPresent(Value.self, forKey: key)) ?? nil) ?? fallback
        }

        self.init(
            currencyCode: value(.currencyCode, default: defaults.currencyCode),
            numberGrouping: value(.numberGrouping, default: defaults.numberGrouping),
            parserMode: value(.parserMode, default: defaults.parserMode),
            faceIDEnabled: value(.faceIDEnabled, default: defaults.faceIDEnabled),
            iCloudBackupEnabled: value(.iCloudBackupEnabled, default: defaults.iCloudBackupEnabled),
            lastBackupAt: (try? container.decodeIfPresent(Date.self, forKey: .lastBackupAt)) ?? nil,
            schemaVersion: value(.schemaVersion, default: defaults.schemaVersion)
        )
    }
}
