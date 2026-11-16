import Foundation

/// A complete backup of the user's data: the versioned JSON file the app exports and imports.
///
/// The document is deliberately independent of the SwiftData schema. Every row is a plain value with
/// a stable ``UUID``, and every relationship is one of those identities, so a file written by one
/// version of the app can be read by another. Amounts are plain decimal strings and dates are
/// ISO-8601 strings, which keeps them free of a locale or a binary encoding surprise; the widget
/// snapshot and the insights caches are derived data and have no place in a backup.
public struct BackupDocument: Codable, Equatable, Sendable {
    /// The format version this document was written in, from ``BackupCodec/currentSchemaVersion``.
    public var schemaVersion: Int
    /// The app version that wrote the file, for diagnostics and for the restore summary.
    public var appVersion: String
    /// When the file was written, as an ISO-8601 instant.
    public var exportedAt: String
    /// The user's settings at export time, without the device-specific backup folder bookmark.
    public var settings: BackupSettings
    /// Every account.
    public var accounts: [BackupAccount]
    /// Every balance checkpoint.
    public var checkpoints: [BackupCheckpoint]
    /// Every transaction.
    public var transactions: [BackupTransaction]
    /// Every raw message, so a restore keeps the history a re-parse needs.
    public var rawMessages: [BackupRawMessage]
    /// Every parsing rule.
    public var parsingRules: [BackupParsingRule]
    /// Every category.
    public var categories: [BackupCategory]
    /// Every keyword categorization rule.
    public var categorizationRules: [BackupCategorizationRule]

    public init(
        schemaVersion: Int = BackupCodec.currentSchemaVersion,
        appVersion: String,
        exportedAt: String,
        settings: BackupSettings,
        accounts: [BackupAccount] = [],
        checkpoints: [BackupCheckpoint] = [],
        transactions: [BackupTransaction] = [],
        rawMessages: [BackupRawMessage] = [],
        parsingRules: [BackupParsingRule] = [],
        categories: [BackupCategory] = [],
        categorizationRules: [BackupCategorizationRule] = []
    ) {
        self.schemaVersion = schemaVersion
        self.appVersion = appVersion
        self.exportedAt = exportedAt
        self.settings = settings
        self.accounts = accounts
        self.checkpoints = checkpoints
        self.transactions = transactions
        self.rawMessages = rawMessages
        self.parsingRules = parsingRules
        self.categories = categories
        self.categorizationRules = categorizationRules
    }
}

/// The settings a backup carries.
///
/// The shape mirrors ``AppSettings`` field for field, but it is its own type on purpose: settings
/// travel to another device in a backup, while the app's backup folder bookmark is specific to this
/// device and must never reach the file.
public struct BackupSettings: Codable, Equatable, Sendable {
    /// The display currency, e.g. "MYR".
    public var currencyCode: String
    /// How amounts are grouped for display.
    public var numberGrouping: NumberGrouping
    /// Whether the app draws in light or dark, or follows the device.
    public var appearanceMode: AppearanceMode
    /// The parser engine used for new raw messages.
    public var parserMode: ParserMode
    /// Whether the app requires Face ID to unlock.
    public var faceIDEnabled: Bool
    /// Whether backups are written to the user's iCloud folder.
    public var iCloudBackupEnabled: Bool
    /// When the last backup completed, as an ISO-8601 instant, when one has.
    public var lastBackupAt: String?
    /// The settings schema version, used when migrating stored documents.
    public var schemaVersion: Int

    public init(
        currencyCode: String,
        numberGrouping: NumberGrouping,
        appearanceMode: AppearanceMode = .system,
        parserMode: ParserMode,
        faceIDEnabled: Bool,
        iCloudBackupEnabled: Bool,
        lastBackupAt: String?,
        schemaVersion: Int
    ) {
        self.currencyCode = currencyCode
        self.numberGrouping = numberGrouping
        self.appearanceMode = appearanceMode
        self.parserMode = parserMode
        self.faceIDEnabled = faceIDEnabled
        self.iCloudBackupEnabled = iCloudBackupEnabled
        self.lastBackupAt = lastBackupAt
        self.schemaVersion = schemaVersion
    }

    /// The backup shape of an app settings value.
    ///
    /// - Parameter settings: The settings to carry into a document.
    public init(_ settings: AppSettings) {
        self.init(
            currencyCode: settings.currencyCode,
            numberGrouping: settings.numberGrouping,
            appearanceMode: settings.appearanceMode,
            parserMode: settings.parserMode,
            faceIDEnabled: settings.faceIDEnabled,
            iCloudBackupEnabled: settings.iCloudBackupEnabled,
            lastBackupAt: settings.lastBackupAt.map(BackupCodec.dateText),
            schemaVersion: settings.schemaVersion
        )
    }

    private enum CodingKeys: String, CodingKey {
        case currencyCode
        case numberGrouping
        case appearanceMode
        case parserMode
        case faceIDEnabled
        case iCloudBackupEnabled
        case lastBackupAt
        case schemaVersion
    }

    /// Reads a backup's settings block.
    ///
    /// Every field a backup has always carried is required, as before. The appearance mode arrived
    /// later, so a backup written before it — or one naming a mode this version cannot read — follows
    /// the device instead of failing the whole restore.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            currencyCode: try container.decode(String.self, forKey: .currencyCode),
            numberGrouping: try container.decode(NumberGrouping.self, forKey: .numberGrouping),
            appearanceMode: ((try? container.decodeIfPresent(AppearanceMode.self, forKey: .appearanceMode)) ?? nil)
                ?? .system,
            parserMode: try container.decode(ParserMode.self, forKey: .parserMode),
            faceIDEnabled: try container.decode(Bool.self, forKey: .faceIDEnabled),
            iCloudBackupEnabled: try container.decode(Bool.self, forKey: .iCloudBackupEnabled),
            lastBackupAt: try container.decodeIfPresent(String.self, forKey: .lastBackupAt),
            schemaVersion: try container.decode(Int.self, forKey: .schemaVersion)
        )
    }

    /// The app settings this document carries, ready for the settings store to save.
    ///
    /// - Throws: ``BackupError/malformedDate(field:value:)`` when ``lastBackupAt`` is not an
    ///   ISO-8601 instant.
    public func makeAppSettings() throws -> AppSettings {
        AppSettings(
            currencyCode: currencyCode,
            numberGrouping: numberGrouping,
            appearanceMode: appearanceMode,
            parserMode: parserMode,
            faceIDEnabled: faceIDEnabled,
            iCloudBackupEnabled: iCloudBackupEnabled,
            lastBackupAt: try lastBackupAt.map { try BackupCodec.date(from: $0, field: "settings.lastBackupAt") },
            schemaVersion: schemaVersion
        )
    }
}

/// An account in a backup.
public struct BackupAccount: Codable, Equatable, Sendable {
    /// The account's stable identity.
    public var id: UUID
    /// The name shown in account pickers.
    public var name: String
    /// Free-text institution name, when one was recorded.
    public var institutionName: String?
    /// The user's preferred ordering.
    public var sortOrder: Int
    /// When the account was created, as an ISO-8601 instant.
    public var createdAt: String
    /// When the account was archived, as an ISO-8601 instant, when it was.
    public var archivedAt: String?

    public init(
        id: UUID,
        name: String,
        institutionName: String?,
        sortOrder: Int,
        createdAt: String,
        archivedAt: String?
    ) {
        self.id = id
        self.name = name
        self.institutionName = institutionName
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.archivedAt = archivedAt
    }
}

/// A balance checkpoint in a backup.
public struct BackupCheckpoint: Codable, Equatable, Sendable {
    /// The checkpoint's stable identity.
    public var id: UUID
    /// The identity of the account the checkpoint belongs to.
    public var accountID: UUID
    /// The observed or declared balance, as a plain decimal string.
    public var amount: String
    /// When the balance was observed, as an ISO-8601 instant.
    public var recordedAt: String
    /// How the checkpoint was established.
    public var source: CheckpointSource
    /// The transaction whose message established this balance, when one did.
    public var sourceTransactionID: UUID?
    /// When the checkpoint was created, as an ISO-8601 instant.
    public var createdAt: String
    /// A user-authored note.
    public var note: String?

    public init(
        id: UUID,
        accountID: UUID,
        amount: String,
        recordedAt: String,
        source: CheckpointSource,
        sourceTransactionID: UUID?,
        createdAt: String,
        note: String?
    ) {
        self.id = id
        self.accountID = accountID
        self.amount = amount
        self.recordedAt = recordedAt
        self.source = source
        self.sourceTransactionID = sourceTransactionID
        self.createdAt = createdAt
        self.note = note
    }
}

/// A transaction in a backup.
public struct BackupTransaction: Codable, Equatable, Sendable {
    /// The transaction's stable identity.
    public var id: UUID
    /// The identity of the account the money moved through.
    public var accountID: UUID
    /// The positive magnitude of the movement, as a plain decimal string.
    public var amount: String
    /// Whether the movement left or entered the account.
    public var direction: Direction
    /// The reporting date, as an ISO-8601 instant.
    public var occurredAt: String
    /// The ingestion date that drives checkpoint balance math, as an ISO-8601 instant.
    public var recordedAt: String
    /// The merchant as extracted.
    public var merchantRaw: String
    /// The merchant trimmed and whitespace-collapsed for display and matching.
    public var merchantDisplay: String
    /// The identity of the assigned category, when the transaction has one.
    public var categoryID: UUID?
    /// How the category was assigned.
    public var categorySource: CategorySource?
    /// The balance the message reported, as a plain decimal string, when it reported one.
    public var balanceAfter: String?
    /// The identity of the raw message the transaction was parsed from, when there was one.
    public var rawMessageID: UUID?
    /// The engine that parsed the transaction.
    public var parseEngine: ParseEngine?
    /// The identity of the rule that produced the parse. It is a weak reference: a rule that has
    /// since been deleted leaves this identity pointing at nothing, which is not a broken document.
    public var matchedRuleID: UUID?
    /// Whether both sides of a transfer are excluded from spend and income reports.
    public var isTransfer: Bool
    /// A user-authored note.
    public var note: String?
    /// When the transaction was created, as an ISO-8601 instant.
    public var createdAt: String
    /// When the transaction was last edited, as an ISO-8601 instant.
    public var updatedAt: String

    public init(
        id: UUID,
        accountID: UUID,
        amount: String,
        direction: Direction,
        occurredAt: String,
        recordedAt: String,
        merchantRaw: String,
        merchantDisplay: String,
        categoryID: UUID?,
        categorySource: CategorySource?,
        balanceAfter: String?,
        rawMessageID: UUID?,
        parseEngine: ParseEngine?,
        matchedRuleID: UUID?,
        isTransfer: Bool,
        note: String?,
        createdAt: String,
        updatedAt: String
    ) {
        self.id = id
        self.accountID = accountID
        self.amount = amount
        self.direction = direction
        self.occurredAt = occurredAt
        self.recordedAt = recordedAt
        self.merchantRaw = merchantRaw
        self.merchantDisplay = merchantDisplay
        self.categoryID = categoryID
        self.categorySource = categorySource
        self.balanceAfter = balanceAfter
        self.rawMessageID = rawMessageID
        self.parseEngine = parseEngine
        self.matchedRuleID = matchedRuleID
        self.isTransfer = isTransfer
        self.note = note
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

/// A raw message in a backup.
public struct BackupRawMessage: Codable, Equatable, Sendable {
    /// The message's stable identity.
    public var id: UUID
    /// The original message text, unmodified.
    public var text: String
    /// The sender, when the shortcut provided it.
    public var sender: String?
    /// The message date, as an ISO-8601 instant.
    public var receivedAt: String
    /// When the message reached the app, as an ISO-8601 instant.
    public var ingestedAt: String
    /// The outcome of parsing the message.
    public var status: ParseStatus
    /// The engine that parsed the message, when one ran.
    public var engine: ParseEngine?
    /// The identity of the rule that matched. Like a transaction's, it is a weak reference.
    public var matchedRuleID: UUID?
    /// A user-facing failure description.
    public var errorDescription: String?
    /// The digest used to deduplicate messages.
    public var fingerprint: String

    public init(
        id: UUID,
        text: String,
        sender: String?,
        receivedAt: String,
        ingestedAt: String,
        status: ParseStatus,
        engine: ParseEngine?,
        matchedRuleID: UUID?,
        errorDescription: String?,
        fingerprint: String
    ) {
        self.id = id
        self.text = text
        self.sender = sender
        self.receivedAt = receivedAt
        self.ingestedAt = ingestedAt
        self.status = status
        self.engine = engine
        self.matchedRuleID = matchedRuleID
        self.errorDescription = errorDescription
        self.fingerprint = fingerprint
    }
}

/// A regex parsing rule in a backup.
public struct BackupParsingRule: Codable, Equatable, Sendable {
    /// The rule's stable identity.
    public var id: UUID
    /// The identity of the account the rule applies to.
    public var accountID: UUID
    /// A display name.
    public var name: String
    /// Whether the rule matches debits or credits.
    public var direction: Direction
    /// The Swift regex with named capture groups.
    public var pattern: String
    /// The format for a captured date group, when the rule has one.
    public var dateFormat: String?
    /// Whether matching ignores case.
    public var isCaseInsensitive: Bool
    /// Whether `.` in the pattern also matches newlines.
    public var dotMatchesNewlines: Bool
    /// The evaluation order; lower values run first.
    public var priority: Int
    /// Whether the rule participates in parsing.
    public var isEnabled: Bool
    /// When the rule was created, as an ISO-8601 instant.
    public var createdAt: String
    /// When the rule was last edited, as an ISO-8601 instant.
    public var updatedAt: String

    public init(
        id: UUID,
        accountID: UUID,
        name: String,
        direction: Direction,
        pattern: String,
        dateFormat: String?,
        isCaseInsensitive: Bool,
        dotMatchesNewlines: Bool,
        priority: Int,
        isEnabled: Bool,
        createdAt: String,
        updatedAt: String
    ) {
        self.id = id
        self.accountID = accountID
        self.name = name
        self.direction = direction
        self.pattern = pattern
        self.dateFormat = dateFormat
        self.isCaseInsensitive = isCaseInsensitive
        self.dotMatchesNewlines = dotMatchesNewlines
        self.priority = priority
        self.isEnabled = isEnabled
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

/// A category in a backup.
public struct BackupCategory: Codable, Equatable, Sendable {
    /// The category's stable identity.
    public var id: UUID
    /// The display name.
    public var name: String
    /// The SF Symbol shown beside the category.
    public var symbolName: String
    /// The token the design system maps to a palette color.
    public var colorToken: String
    /// The user's preferred ordering.
    public var sortOrder: Int
    /// Whether the category ships with the app and cannot be deleted.
    public var isSystem: Bool

    public init(
        id: UUID,
        name: String,
        symbolName: String,
        colorToken: String,
        sortOrder: Int,
        isSystem: Bool
    ) {
        self.id = id
        self.name = name
        self.symbolName = symbolName
        self.colorToken = colorToken
        self.sortOrder = sortOrder
        self.isSystem = isSystem
    }
}

/// A keyword categorization rule in a backup.
public struct BackupCategorizationRule: Codable, Equatable, Sendable {
    /// The rule's stable identity.
    public var id: UUID
    /// The keyword matched case-insensitively against the merchant.
    public var keyword: String
    /// The identity of the category assigned when the keyword matches.
    public var categoryID: UUID
    /// The evaluation order; lower values run first.
    public var priority: Int
    /// Whether the rule participates in categorization.
    public var isEnabled: Bool

    public init(id: UUID, keyword: String, categoryID: UUID, priority: Int, isEnabled: Bool) {
        self.id = id
        self.keyword = keyword
        self.categoryID = categoryID
        self.priority = priority
        self.isEnabled = isEnabled
    }
}

/// A reason a backup could not be read, validated, or imported.
///
/// Every case names the part of the document at fault, so the restore UI can tell the user what a
/// file contains that this app cannot accept instead of failing with "invalid backup".
public enum BackupError: Error, Equatable, Sendable {
    /// The document was written by a schema version this app does not read.
    case unsupportedVersion(found: Int)
    /// Two rows in the document claim the same identity.
    case duplicateID(UUID)
    /// A row names a record the document does not contain.
    case brokenReference(field: String, id: UUID)
    /// An amount is not a plain, locale-independent decimal string.
    case malformedDecimal(field: String, value: String)
    /// A date is not an ISO-8601 instant.
    case malformedDate(field: String, value: String)
    /// An account has no checkpoint, so its balance could not be computed after a restore.
    case accountWithoutCheckpoint(UUID)
    /// The data is not a JSON document this app can read: truncated, corrupt, or another file.
    case invalidFile(reason: String)
}
