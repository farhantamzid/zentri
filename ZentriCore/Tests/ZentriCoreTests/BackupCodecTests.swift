import Foundation
import Testing
@testable import ZentriCore

// `ZentriCore.Category` and `ZentriCore.Transaction` are qualified where their bare names would be
// ambiguous with the Objective-C runtime names Foundation imports. The backup DTOs carry their own
// names (`BackupCategory`, `BackupTransaction`), so they never need qualifying.

/// A stable identity built from one byte, so a fixture's ids are readable and repeatable.
private func backupID(_ value: UInt8) -> UUID {
    UUID(uuid: (value, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))
}

/// A money value built exactly from cents, so no test depends on a locale or on decimal text.
private func cents(_ value: Int) -> Decimal {
    Decimal(sign: value < 0 ? .minus : .plus, exponent: -2, significand: Decimal(abs(value)))
}

/// The settings a fixture backup carries: everything the app stores except the device bookmark.
private func fixtureSettings() -> BackupSettings {
    BackupSettings(
        currencyCode: "MYR",
        numberGrouping: .indian,
        parserMode: .rules,
        faceIDEnabled: true,
        iCloudBackupEnabled: true,
        lastBackupAt: "2026-11-17T08:00:00.000Z",
        schemaVersion: 1
    )
}

/// A complete document: two accounts, checkpoints, transactions, messages, rules, categories, settings.
///
/// Every date is an ISO-8601 string with fractional seconds, which is what the exporter writes, and
/// every amount is a plain decimal string, so the fixture is the format the spec describes.
private func fixtureDocument() -> BackupDocument {
    BackupDocument(
        schemaVersion: 1,
        appVersion: "1.4.0",
        exportedAt: "2026-11-18T11:06:40.000Z",
        settings: fixtureSettings(),
        accounts: [
            BackupAccount(
                id: backupID(1),
                name: "Everyday",
                institutionName: "Bank",
                sortOrder: 0,
                createdAt: "2026-01-02T03:04:05.000Z",
                archivedAt: nil
            ),
            BackupAccount(
                id: backupID(2),
                name: "Savings",
                institutionName: nil,
                sortOrder: 1,
                createdAt: "2026-01-03T03:04:05.000Z",
                archivedAt: "2026-06-01T00:00:00.000Z"
            ),
        ],
        checkpoints: [
            BackupCheckpoint(
                id: backupID(10),
                accountID: backupID(1),
                amount: "1500.25",
                recordedAt: "2026-11-01T09:00:00.000Z",
                source: .opening,
                sourceTransactionID: nil,
                createdAt: "2026-11-01T09:00:00.000Z",
                note: "Opening balance"
            ),
            BackupCheckpoint(
                id: backupID(11),
                accountID: backupID(2),
                amount: "-25.5",
                recordedAt: "2026-11-02T09:00:00.000Z",
                source: .sms,
                sourceTransactionID: backupID(20),
                createdAt: "2026-11-02T09:00:00.000Z",
                note: nil
            ),
        ],
        transactions: [
            BackupTransaction(
                id: backupID(20),
                accountID: backupID(2),
                amount: "12.5",
                direction: .debit,
                occurredAt: "2026-11-02T08:59:00.000Z",
                recordedAt: "2026-11-02T09:00:00.000Z",
                merchantRaw: "KFC",
                merchantDisplay: "KFC",
                categoryID: backupID(30),
                categorySource: .rule,
                balanceAfter: "-25.5",
                rawMessageID: backupID(40),
                parseEngine: .rules,
                matchedRuleID: backupID(50),
                isTransfer: false,
                note: nil,
                createdAt: "2026-11-02T09:00:00.000Z",
                updatedAt: "2026-11-02T09:00:00.000Z"
            ),
        ],
        rawMessages: [
            BackupRawMessage(
                id: backupID(40),
                text: "MYBANK: RM12.50 spent at KFC",
                sender: "MYBANK",
                receivedAt: "2026-11-02T08:59:00.000Z",
                ingestedAt: "2026-11-02T09:00:00.000Z",
                status: .parsed,
                engine: .rules,
                matchedRuleID: backupID(50),
                errorDescription: nil,
                fingerprint: "fingerprint-kfc"
            ),
        ],
        parsingRules: [
            BackupParsingRule(
                id: backupID(50),
                accountID: backupID(1),
                name: "Debit — card",
                direction: .debit,
                pattern: "spent (?<amount>[\\d.]+) at (?<merchant>.+)",
                dateFormat: "dd/MM/yy",
                isCaseInsensitive: true,
                dotMatchesNewlines: false,
                priority: 0,
                isEnabled: true,
                createdAt: "2026-01-02T03:04:05.000Z",
                updatedAt: "2026-01-02T03:04:05.000Z"
            ),
        ],
        categories: [
            BackupCategory(
                id: backupID(30),
                name: "Dining",
                symbolName: "fork.knife",
                colorToken: "coral",
                sortOrder: 2,
                isSystem: true
            ),
            BackupCategory(
                id: backupID(31),
                name: "Other",
                symbolName: "ellipsis",
                colorToken: "slate",
                sortOrder: 11,
                isSystem: true
            ),
        ],
        categorizationRules: [
            BackupCategorizationRule(
                id: backupID(60),
                keyword: "kfc",
                categoryID: backupID(30),
                priority: 0,
                isEnabled: true
            ),
        ]
    )
}

/// The backup error `body` throws, or a recorded failure when it throws anything else.
private func backupError(from body: () throws -> Void) -> BackupError? {
    do {
        try body()
        Issue.record("expected a BackupError but nothing was thrown")
        return nil
    } catch let error as BackupError {
        return error
    } catch {
        Issue.record("expected a BackupError but got \(error)")
        return nil
    }
}

/// The error decoding `document`'s encoded form throws.
private func decodingError(of document: BackupDocument) -> BackupError? {
    backupError {
        _ = try BackupCodec.decode(try BackupCodec.encode(document))
    }
}

// MARK: - Round trip

@Test func roundTripsAWholeDocument() throws {
    let document = fixtureDocument()

    let data = try BackupCodec.encode(document)
    let decoded = try BackupCodec.decode(data)

    #expect(decoded == document)
    #expect(decoded.schemaVersion == BackupCodec.currentSchemaVersion)
    #expect(decoded.appVersion == "1.4.0")
    #expect(decoded.settings == fixtureSettings())
}

@Test func roundTripsSettingsWithoutABackupHistory() throws {
    var document = fixtureDocument()
    document.settings.lastBackupAt = nil

    let decoded = try BackupCodec.decode(try BackupCodec.encode(document))

    #expect(decoded == document)
    #expect(try decoded.settings.makeAppSettings().lastBackupAt == nil)
}

@Test func writesAmountsAndDatesAsStrings() throws {
    let data = try BackupCodec.encode(fixtureDocument())
    let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])

    let transactions = try #require(json["transactions"] as? [[String: Any]])
    #expect(transactions.first?["amount"] as? String == "12.5")
    #expect(transactions.first?["balanceAfter"] as? String == "-25.5")
    #expect(transactions.first?["occurredAt"] as? String == "2026-11-02T08:59:00.000Z")

    let checkpoints = try #require(json["checkpoints"] as? [[String: Any]])
    #expect(checkpoints.first?["amount"] as? String == "1500.25")
    #expect(checkpoints.first?["recordedAt"] as? String == "2026-11-01T09:00:00.000Z")

    #expect(json["exportedAt"] as? String == "2026-11-18T11:06:40.000Z")
    #expect(json["schemaVersion"] as? Int == 1)

    // Exactly the documented top-level shape: derived data (widget snapshots, insights caches) has
    // no place in a backup.
    #expect(Set(json.keys) == Set([
        "schemaVersion", "appVersion", "exportedAt", "settings", "accounts", "checkpoints",
        "transactions", "rawMessages", "parsingRules", "categories", "categorizationRules",
    ]))

    // Settings travel as their own shape, which is what keeps a device-specific folder bookmark out.
    let settings = try #require(json["settings"] as? [String: Any])
    #expect(Set(settings.keys) == Set([
        "currencyCode", "numberGrouping", "parserMode", "faceIDEnabled", "iCloudBackupEnabled",
        "lastBackupAt", "schemaVersion",
    ]))
}

@Test func encodesKeysInSortedOrder() throws {
    let data = try BackupCodec.encode(fixtureDocument())
    let text = try #require(String(data: data, encoding: .utf8))
    let keys = [
        "\"accounts\"", "\"appVersion\"", "\"categories\"", "\"categorizationRules\"",
        "\"checkpoints\"", "\"exportedAt\"", "\"parsingRules\"", "\"rawMessages\"",
        "\"schemaVersion\"", "\"settings\"", "\"transactions\"",
    ]

    let positions = try keys.map { key in
        try #require(text.range(of: key), "missing key \(key)").lowerBound
    }
    #expect(positions == positions.sorted())
}

@Test func readsDatesWithAndWithoutFractionalSeconds() throws {
    var document = fixtureDocument()
    document.exportedAt = "2026-11-18T11:06:40Z"
    document.accounts[0].createdAt = "2026-01-02T03:04:05Z"
    document.rawMessages[0].receivedAt = "2026-11-02T08:59:00Z"

    let decoded = try BackupCodec.decode(try BackupCodec.encode(document))

    #expect(decoded == document)
}

@Test func convertsAmountsToPlainStringsAndBackExactly() throws {
    #expect(BackupCodec.moneyText(cents(1250)) == "12.5")
    #expect(BackupCodec.moneyText(cents(-25)) == "-0.25")
    #expect(BackupCodec.moneyText(0) == "0")

    #expect(try BackupCodec.decimal(from: "12.50", field: "amount") == cents(1250))
    #expect(try BackupCodec.decimal(from: "-0.01", field: "amount") == cents(-1))
    #expect(try BackupCodec.decimal(from: "0", field: "amount") == 0)

    let large = "123456789012345678901234567890.123456789"
    #expect(try BackupCodec.decimal(from: large, field: "amount") == Decimal(string: large))
}

@Test func rejectsAmountsThatAreNotPlainDecimals() {
    for value in ["", "-", "1,5", "12abc", "1e3", ".5", "5.", "+5", " 5", "NaN", "1.2.3", "١٢"] {
        let error = backupError { _ = try BackupCodec.decimal(from: value, field: "amount") }
        guard case .malformedDecimal(let field, let rejected) = error else {
            Issue.record("expected malformedDecimal for '\(value)', got \(String(describing: error))")
            continue
        }
        #expect(field == "amount")
        #expect(rejected == value)
    }
}

// MARK: - Rejected documents

@Test func rejectsAnUnsupportedSchemaVersion() {
    var document = fixtureDocument()
    document.schemaVersion = 2

    #expect(decodingError(of: document) == .unsupportedVersion(found: 2))
}

@Test func rejectsGarbageBytes() {
    let error = backupError { _ = try BackupCodec.decode(Data("this is not a backup".utf8)) }

    guard case .invalidFile = error else {
        Issue.record("expected invalidFile, got \(String(describing: error))")
        return
    }
}

@Test func rejectsATruncatedDocument() throws {
    let data = try BackupCodec.encode(fixtureDocument())

    let error = backupError { _ = try BackupCodec.decode(Data(data.prefix(40))) }

    guard case .invalidFile = error else {
        Issue.record("expected invalidFile, got \(String(describing: error))")
        return
    }
}

@Test func rejectsAMalformedDecimal() {
    var document = fixtureDocument()
    document.transactions[0].amount = "12.5.6"

    let error = decodingError(of: document)
    guard case .malformedDecimal(let field, let value) = error else {
        Issue.record("expected malformedDecimal, got \(String(describing: error))")
        return
    }
    #expect(field == "transactions[\(backupID(20).uuidString)].amount")
    #expect(value == "12.5.6")
}

@Test func rejectsAMalformedDate() {
    var document = fixtureDocument()
    document.checkpoints[0].recordedAt = "yesterday"

    let error = decodingError(of: document)
    guard case .malformedDate(let field, let value) = error else {
        Issue.record("expected malformedDate, got \(String(describing: error))")
        return
    }
    #expect(field == "checkpoints[\(backupID(10).uuidString)].recordedAt")
    #expect(value == "yesterday")
}

@Test func rejectsAMalformedSettingsDate() {
    var document = fixtureDocument()
    document.settings.lastBackupAt = "last week"

    let error = decodingError(of: document)
    guard case .malformedDate(let field, let value) = error else {
        Issue.record("expected malformedDate, got \(String(describing: error))")
        return
    }
    #expect(field == "settings.lastBackupAt")
    #expect(value == "last week")
    #expect(throws: BackupError.malformedDate(field: "settings.lastBackupAt", value: "last week")) {
        _ = try document.settings.makeAppSettings()
    }
}

@Test func rejectsADuplicateIdentity() {
    var document = fixtureDocument()
    document.categories.append(document.categories[0])

    #expect(decodingError(of: document) == .duplicateID(backupID(30)))
}

@Test func rejectsABrokenAccountReference() {
    var document = fixtureDocument()
    document.checkpoints[0].accountID = backupID(99)

    let error = decodingError(of: document)
    guard case .brokenReference(let field, let id) = error else {
        Issue.record("expected brokenReference, got \(String(describing: error))")
        return
    }
    #expect(field == "checkpoints[\(backupID(10).uuidString)].accountID")
    #expect(id == backupID(99))
}

@Test func rejectsABrokenCategoryReference() {
    var document = fixtureDocument()
    document.categorizationRules[0].categoryID = backupID(99)

    let error = decodingError(of: document)
    guard case .brokenReference(let field, let id) = error else {
        Issue.record("expected brokenReference, got \(String(describing: error))")
        return
    }
    #expect(field == "categorizationRules[\(backupID(60).uuidString)].categoryID")
    #expect(id == backupID(99))
}

@Test func rejectsABrokenRawMessageReference() {
    var document = fixtureDocument()
    document.transactions[0].rawMessageID = backupID(99)

    let error = decodingError(of: document)
    guard case .brokenReference(let field, let id) = error else {
        Issue.record("expected brokenReference, got \(String(describing: error))")
        return
    }
    #expect(field == "transactions[\(backupID(20).uuidString)].rawMessageID")
    #expect(id == backupID(99))
}

@Test func rejectsAnAccountWithoutACheckpoint() {
    var document = fixtureDocument()
    document.checkpoints.removeAll { $0.accountID == backupID(1) }

    #expect(decodingError(of: document) == .accountWithoutCheckpoint(backupID(1)))
}

@Test func acceptsAReferenceToARuleTheDocumentNoLongerCarries() throws {
    var document = fixtureDocument()
    document.transactions[0].matchedRuleID = backupID(99)
    document.rawMessages[0].matchedRuleID = backupID(99)
    document.parsingRules = []

    let decoded = try BackupCodec.decode(try BackupCodec.encode(document))

    #expect(decoded.transactions[0].matchedRuleID == backupID(99))
    #expect(decoded.rawMessages[0].matchedRuleID == backupID(99))
    #expect(decoded.parsingRules.isEmpty)
}

// MARK: - Date text (I3)

/// The exact text a backup stores for an instant: UTC, millisecond fractions, `Z`. Pinned so a
/// faster implementation stays byte-compatible with backups already written.
@Test func backupDateTextIsUnchanged() throws {
    let cases: [(Date, String)] = [
        (Date(timeIntervalSince1970: 1_795_000_000), "2026-11-18T11:06:40.000Z"),
        (Date(timeIntervalSince1970: 1_795_000_000.125), "2026-11-18T11:06:40.125Z"),
        (Date(timeIntervalSince1970: 0), "1970-01-01T00:00:00.000Z"),
        (Date(timeIntervalSince1970: 951_782_400.5), "2000-02-29T00:00:00.500Z"),
    ]
    for (date, text) in cases {
        #expect(BackupCodec.dateText(date) == text)
        #expect(try BackupCodec.date(from: text, field: "test") == date)
    }
    // The whole-second form other tools write is still read, and nonsense is still refused.
    #expect(try BackupCodec.date(from: "2026-11-18T11:06:40Z", field: "test") == Date(timeIntervalSince1970: 1_795_000_000))
    #expect(throws: BackupError.self) { try BackupCodec.date(from: "18/11/2026", field: "test") }
}

/// A coarse guard: a store of a few thousand rows holds tens of thousands of dates, and writing and
/// reading them must not take seconds. Building a formatter per date did.
@Test func backupDatesAreWrittenAndReadQuickly() throws {
    let start = ContinuousClock.now
    for index in 0..<20_000 {
        let text = BackupCodec.dateText(Date(timeIntervalSince1970: 1_795_000_000 + Double(index)))
        _ = try BackupCodec.date(from: text, field: "test")
    }
    #expect(ContinuousClock.now - start < .seconds(3))
}
