import Foundation
import SwiftData
import Testing
@testable import ZentriCore

// `ZentriCore.Category` and `ZentriCore.Transaction` are qualified below because Foundation imports
// the Objective-C runtime's names. The backup DTOs (`BackupCategory`, `BackupTransaction`) are
// distinct names, so they never need qualifying.

/// 2026-11-18 11:06:40 UTC. Every fixture date is a whole second, so the ISO-8601 text a backup
/// stores reproduces it exactly.
private let storedNow = Date(timeIntervalSince1970: 1_795_000_000)

/// A stable identity built from one byte, so fixture ids are readable and repeatable.
private func backupID(_ value: UInt8) -> UUID {
    UUID(uuid: (value, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))
}

/// A money value built exactly from cents, so no test depends on a locale or on decimal text.
private func cents(_ value: Int) -> Decimal {
    Decimal(sign: value < 0 ? .minus : .plus, exponent: -2, significand: Decimal(abs(value)))
}

/// The settings an export carries: everything the app stores except the device bookmark.
private func fixtureSettings() -> AppSettings {
    AppSettings(
        currencyCode: "MYR",
        numberGrouping: .indian,
        parserMode: .rules,
        faceIDEnabled: true,
        iCloudBackupEnabled: true,
        lastBackupAt: storedNow.addingTimeInterval(-3_600),
        schemaVersion: 1
    )
}

/// The error the import's save hook throws in place of a store that cannot be written.
private enum ImportSaveFailure: Error, Equatable {
    case storeIsUnwritable
}

// MARK: - Store fixtures

/// A store whose rows have fixed identities, so a merge target can overlap them deliberately.
@MainActor
private func makeFixedStore() throws -> ModelContext {
    let container = try ZentriContainer.make(inMemory: true)
    let context = ModelContext(container)

    let everyday = Account(
        id: backupID(1),
        name: "Everyday",
        institutionName: "Bank",
        sortOrder: 0,
        createdAt: storedNow.addingTimeInterval(-86_400)
    )
    let savings = Account(
        id: backupID(2),
        name: "Savings",
        institutionName: nil,
        sortOrder: 1,
        createdAt: storedNow.addingTimeInterval(-172_800)
    )
    context.insert(everyday)
    context.insert(savings)

    let groceries = ZentriCore.Category(
        id: backupID(32),
        name: "Groceries",
        symbolName: "cart",
        colorToken: "green",
        sortOrder: 0,
        isSystem: true
    )
    let dining = ZentriCore.Category(
        id: backupID(31),
        name: "Dining",
        symbolName: "fork.knife",
        colorToken: "coral",
        sortOrder: 1,
        isSystem: false
    )
    context.insert(groceries)
    context.insert(dining)

    let message = RawMessage(
        id: backupID(41),
        text: "MYBANK: RM12.50 spent at KFC",
        sender: "MYBANK",
        receivedAt: storedNow.addingTimeInterval(-60),
        ingestedAt: storedNow.addingTimeInterval(-30),
        status: .parsed,
        engine: .rules,
        matchedRuleID: backupID(51),
        errorDescription: nil,
        fingerprint: "fingerprint-kfc"
    )
    let ignored = RawMessage(
        id: backupID(42),
        text: "Your one-time password is 123456",
        sender: "MYBANK",
        receivedAt: storedNow.addingTimeInterval(-600),
        ingestedAt: storedNow.addingTimeInterval(-540),
        status: .ignored,
        engine: nil,
        matchedRuleID: nil,
        errorDescription: nil,
        fingerprint: "fingerprint-otp"
    )
    context.insert(message)
    context.insert(ignored)

    let opening = BalanceCheckpoint(
        id: backupID(10),
        account: everyday,
        amount: cents(150_025),
        recordedAt: storedNow.addingTimeInterval(-86_400),
        source: .opening,
        createdAt: storedNow.addingTimeInterval(-86_400),
        note: "Opening balance"
    )
    let sms = BalanceCheckpoint(
        id: backupID(11),
        account: savings,
        amount: cents(-2_550),
        recordedAt: storedNow.addingTimeInterval(-30),
        source: .sms,
        sourceTransactionID: backupID(23),
        createdAt: storedNow.addingTimeInterval(-30)
    )
    context.insert(opening)
    context.insert(sms)

    let rule = ParsingRule(
        id: backupID(51),
        account: everyday,
        name: "Debit — card",
        direction: .debit,
        pattern: "spent (?<amount>[\\d.]+) at (?<merchant>.+)",
        dateFormat: "dd/MM/yy",
        isCaseInsensitive: true,
        dotMatchesNewlines: false,
        priority: 0,
        isEnabled: true,
        createdAt: storedNow.addingTimeInterval(-86_400),
        updatedAt: storedNow.addingTimeInterval(-3_600)
    )
    context.insert(rule)

    let categoryRule = CategorizationRule(
        id: backupID(61),
        keyword: "kfc",
        category: dining,
        priority: 0,
        isEnabled: true
    )
    context.insert(categoryRule)

    let kfc = ZentriCore.Transaction(
        id: backupID(23),
        account: everyday,
        amount: cents(1_250),
        direction: .debit,
        occurredAt: storedNow.addingTimeInterval(-7_200),
        recordedAt: storedNow.addingTimeInterval(-30),
        merchantRaw: "KFC",
        merchantDisplay: "KFC",
        category: dining,
        categorySource: .rule,
        balanceAfter: cents(-2_550),
        rawMessage: message,
        parseEngine: .rules,
        matchedRuleID: backupID(51),
        isTransfer: false,
        note: nil,
        createdAt: storedNow.addingTimeInterval(-30),
        updatedAt: storedNow.addingTimeInterval(-30)
    )
    let market = ZentriCore.Transaction(
        id: backupID(21),
        account: everyday,
        amount: cents(4_200),
        direction: .debit,
        occurredAt: storedNow.addingTimeInterval(-3_600),
        recordedAt: storedNow.addingTimeInterval(-3_540),
        merchantRaw: "Corner Market",
        merchantDisplay: "Corner Market",
        category: groceries,
        categorySource: .manual,
        balanceAfter: nil,
        rawMessage: nil,
        parseEngine: .manual,
        matchedRuleID: nil,
        isTransfer: false,
        note: "Weekly shop",
        createdAt: storedNow.addingTimeInterval(-3_540),
        updatedAt: storedNow.addingTimeInterval(-3_540)
    )
    let salary = ZentriCore.Transaction(
        id: backupID(22),
        account: savings,
        amount: cents(250_000),
        direction: .credit,
        occurredAt: storedNow.addingTimeInterval(-10_800),
        recordedAt: storedNow.addingTimeInterval(-10_740),
        merchantRaw: "Salary",
        merchantDisplay: "Salary",
        category: groceries,
        categorySource: .manual,
        balanceAfter: cents(247_450),
        rawMessage: nil,
        parseEngine: nil,
        matchedRuleID: nil,
        isTransfer: true,
        note: nil,
        createdAt: storedNow.addingTimeInterval(-10_740),
        updatedAt: storedNow.addingTimeInterval(-10_740)
    )
    context.insert(kfc)
    context.insert(market)
    context.insert(salary)

    try context.save()
    return context
}

/// A store that deliberately overlaps the fixed store, so a merge has something to skip.
///
/// The overlapping rows carry different values from the backup: account 1 is renamed, category 31 is
/// renamed, transaction 21 and checkpoint 10 hold another amount, parsing rule 51 holds another
/// pattern, and raw message 99 carries the backup's fingerprint under a different identity.
@MainActor
private func makeMergeTarget() throws -> ModelContext {
    let container = try ZentriContainer.make(inMemory: true)
    let context = ModelContext(container)

    let renamed = Account(
        id: backupID(1),
        name: "Renamed everyday",
        institutionName: nil,
        sortOrder: 0,
        createdAt: storedNow.addingTimeInterval(-999_999)
    )
    let extra = Account(
        id: backupID(98),
        name: "Extra",
        institutionName: "Credit union",
        sortOrder: 1,
        createdAt: storedNow.addingTimeInterval(-999_999)
    )
    context.insert(renamed)
    context.insert(extra)

    let dining = ZentriCore.Category(
        id: backupID(31),
        name: "Renamed dining",
        symbolName: "bag",
        colorToken: "amber",
        sortOrder: 0,
        isSystem: false
    )
    context.insert(dining)

    let existingMessage = RawMessage(
        id: backupID(99),
        text: "MYBANK: RM12.50 spent at KFC",
        sender: "MYBANK",
        receivedAt: storedNow.addingTimeInterval(-60),
        ingestedAt: storedNow.addingTimeInterval(-60),
        status: .failed,
        errorDescription: "The merchant is missing.",
        fingerprint: "fingerprint-kfc"
    )
    context.insert(existingMessage)

    let existingCheckpoint = BalanceCheckpoint(
        id: backupID(10),
        account: renamed,
        amount: cents(99_900),
        recordedAt: storedNow.addingTimeInterval(-999_999),
        source: .manual,
        createdAt: storedNow.addingTimeInterval(-999_999)
    )
    context.insert(existingCheckpoint)

    let existingRule = ParsingRule(
        id: backupID(51),
        account: renamed,
        name: "Existing",
        direction: .debit,
        pattern: "already here",
        priority: 0,
        isEnabled: true,
        createdAt: storedNow.addingTimeInterval(-999_999),
        updatedAt: storedNow.addingTimeInterval(-999_999)
    )
    context.insert(existingRule)

    let existingTransaction = ZentriCore.Transaction(
        id: backupID(21),
        account: renamed,
        amount: cents(99_900),
        direction: .debit,
        occurredAt: storedNow.addingTimeInterval(-999_999),
        recordedAt: storedNow.addingTimeInterval(-999_999),
        merchantRaw: "Already here",
        merchantDisplay: "Already here",
        category: dining,
        categorySource: .manual,
        parseEngine: .manual,
        isTransfer: false,
        note: "Do not touch",
        createdAt: storedNow.addingTimeInterval(-999_999),
        updatedAt: storedNow.addingTimeInterval(-999_999)
    )
    context.insert(existingTransaction)

    try context.save()
    return context
}

/// A store whose fingerprint-matching message already anchors a transaction of its own.
///
/// Account 1, category 31, and message 99 overlap the fixed store's backup. Message 99 carries the
/// backup message 41's fingerprint and is already the provenance of transaction 77, so a merge that
/// maps the document's message identity onto it must not re-point it.
@MainActor
private func makeAnchoredMessageTarget() throws -> ModelContext {
    let container = try ZentriContainer.make(inMemory: true)
    let context = ModelContext(container)

    let everyday = Account(
        id: backupID(1),
        name: "Renamed everyday",
        institutionName: nil,
        sortOrder: 0,
        createdAt: storedNow.addingTimeInterval(-999_999)
    )
    context.insert(everyday)

    let dining = ZentriCore.Category(
        id: backupID(31),
        name: "Renamed dining",
        symbolName: "bag",
        colorToken: "amber",
        sortOrder: 0,
        isSystem: false
    )
    context.insert(dining)

    let existingMessage = RawMessage(
        id: backupID(99),
        text: "MYBANK: RM12.50 spent at KFC",
        sender: "MYBANK",
        receivedAt: storedNow.addingTimeInterval(-60),
        ingestedAt: storedNow.addingTimeInterval(-120),
        status: .failed,
        engine: nil,
        matchedRuleID: nil,
        errorDescription: "The merchant is missing.",
        fingerprint: "fingerprint-kfc"
    )
    context.insert(existingMessage)

    let existingTransaction = ZentriCore.Transaction(
        id: backupID(77),
        account: everyday,
        amount: cents(99_900),
        direction: .debit,
        occurredAt: storedNow.addingTimeInterval(-999_999),
        recordedAt: storedNow.addingTimeInterval(-999_999),
        merchantRaw: "Already parsed",
        merchantDisplay: "Already parsed",
        category: dining,
        categorySource: .manual,
        rawMessage: existingMessage,
        parseEngine: .manual,
        isTransfer: false,
        note: "Keep this transaction",
        createdAt: storedNow.addingTimeInterval(-999_999),
        updatedAt: storedNow.addingTimeInterval(-999_999)
    )
    context.insert(existingTransaction)

    try context.save()
    return context
}

/// A seeded store and the backup it exported, so the replace test restores a real install's data.
@MainActor
private struct SeededStore {
    let context: ModelContext
    let settings: AppSettings
    let document: BackupDocument
}

@MainActor
private func makeSeededStore() throws -> SeededStore {
    let container = try ZentriContainer.make(inMemory: true)
    let context = ModelContext(container)
    try SeedData.seed(into: context)

    let categories = try context.fetch(FetchDescriptor<ZentriCore.Category>())
    let dining = try #require(categories.first { $0.name == "Dining" })
    let settings = fixtureSettings()

    let everyday = Account(
        id: backupID(1),
        name: "Everyday",
        institutionName: "Bank",
        sortOrder: 0,
        createdAt: storedNow.addingTimeInterval(-86_400)
    )
    let savings = Account(
        id: backupID(2),
        name: "Savings",
        institutionName: nil,
        sortOrder: 1,
        createdAt: storedNow.addingTimeInterval(-172_800),
        archivedAt: storedNow.addingTimeInterval(-3_600)
    )
    context.insert(everyday)
    context.insert(savings)

    let message = RawMessage(
        id: backupID(41),
        text: "MYBANK: RM12.50 spent at KFC",
        sender: "MYBANK",
        receivedAt: storedNow.addingTimeInterval(-60),
        ingestedAt: storedNow.addingTimeInterval(-30),
        status: .parsed,
        engine: .rules,
        matchedRuleID: nil,
        fingerprint: "fingerprint-kfc"
    )
    context.insert(message)

    let rule = ParsingRule(
        id: backupID(51),
        account: everyday,
        name: "Debit — card",
        direction: .debit,
        pattern: "spent (?<amount>[\\d.]+) at (?<merchant>.+)",
        dateFormat: "dd/MM/yy",
        isCaseInsensitive: false,
        dotMatchesNewlines: true,
        priority: 2,
        isEnabled: true,
        createdAt: storedNow.addingTimeInterval(-86_400),
        updatedAt: storedNow.addingTimeInterval(-3_600)
    )
    context.insert(rule)

    let checkpoint = BalanceCheckpoint(
        id: backupID(10),
        account: everyday,
        amount: cents(150_025),
        recordedAt: storedNow.addingTimeInterval(-86_400),
        source: .opening,
        createdAt: storedNow.addingTimeInterval(-86_400),
        note: "Opening balance"
    )
    context.insert(checkpoint)

    let transaction = ZentriCore.Transaction(
        id: backupID(23),
        account: everyday,
        amount: cents(1_250),
        direction: .debit,
        occurredAt: storedNow.addingTimeInterval(-7_200),
        recordedAt: storedNow.addingTimeInterval(-30),
        merchantRaw: "KFC",
        merchantDisplay: "KFC",
        category: dining,
        categorySource: .rule,
        balanceAfter: cents(-2_550),
        rawMessage: message,
        parseEngine: .rules,
        matchedRuleID: rule.id,
        isTransfer: false,
        note: nil,
        createdAt: storedNow.addingTimeInterval(-30),
        updatedAt: storedNow.addingTimeInterval(-30)
    )
    context.insert(transaction)

    // The archived account needs a checkpoint of its own, which a backup requires of every account.
    let archivedCheckpoint = BalanceCheckpoint(
        id: backupID(11),
        account: savings,
        amount: cents(500_000),
        recordedAt: storedNow.addingTimeInterval(-172_800),
        source: .manual,
        createdAt: storedNow.addingTimeInterval(-172_800)
    )
    context.insert(archivedCheckpoint)

    try context.save()

    let document = try BackupExporter(settings: settings).export(context: context, appVersion: "1.4.0")

    return SeededStore(context: context, settings: settings, document: document)
}

// MARK: - Helpers

/// The stored row of `type` whose identity is `id`, or `nil` when it is missing.
@MainActor
private func storedRow<T: PersistentModel>(
    _ type: T.Type,
    id: UUID,
    in context: ModelContext,
    identifying idKeyPath: KeyPath<T, UUID>
) throws -> T? {
    try context.fetch(FetchDescriptor<T>()).first { $0[keyPath: idKeyPath] == id }
}

/// The rows the store holds, counted per kind.
@MainActor
private func storeCounts(_ context: ModelContext) throws -> ImportSummary.RowCounts {
    ImportSummary.RowCounts(
        accounts: try context.fetchCount(FetchDescriptor<Account>()),
        checkpoints: try context.fetchCount(FetchDescriptor<BalanceCheckpoint>()),
        transactions: try context.fetchCount(FetchDescriptor<ZentriCore.Transaction>()),
        rawMessages: try context.fetchCount(FetchDescriptor<RawMessage>()),
        parsingRules: try context.fetchCount(FetchDescriptor<ParsingRule>()),
        categories: try context.fetchCount(FetchDescriptor<ZentriCore.Category>()),
        categorizationRules: try context.fetchCount(FetchDescriptor<CategorizationRule>())
    )
}

/// The rows the document describes, counted per kind.
private func documentCounts(_ document: BackupDocument) -> ImportSummary.RowCounts {
    ImportSummary.RowCounts(
        accounts: document.accounts.count,
        checkpoints: document.checkpoints.count,
        transactions: document.transactions.count,
        rawMessages: document.rawMessages.count,
        parsingRules: document.parsingRules.count,
        categories: document.categories.count,
        categorizationRules: document.categorizationRules.count
    )
}

/// Deletes every row a backup can restore, the way the app clears its store before a full restore.
@MainActor
private func clearStore(_ context: ModelContext) throws {
    for account in try context.fetch(FetchDescriptor<Account>()) { context.delete(account) }
    for category in try context.fetch(FetchDescriptor<ZentriCore.Category>()) { context.delete(category) }
    for message in try context.fetch(FetchDescriptor<RawMessage>()) { context.delete(message) }
    try context.save()
}

/// A fresh JSON document, as a file importer would hand one over.
private func encodedCopy(of document: BackupDocument) throws -> BackupDocument {
    try BackupCodec.decode(try BackupCodec.encode(document))
}

// MARK: - Export

@Test @MainActor func exportsEveryRowAndTheSettings() throws {
    let context = try makeFixedStore()
    let settings = fixtureSettings()

    let document = try BackupExporter(settings: settings).export(context: context, appVersion: "1.4.0")

    #expect(document.schemaVersion == BackupCodec.currentSchemaVersion)
    #expect(document.appVersion == "1.4.0")
    #expect(document.settings == BackupSettings(settings))
    #expect(try document.settings.makeAppSettings() == settings)

    // Collections follow the store's natural order with the identity as a tiebreak, which is what
    // makes two exports of the same store identical.
    #expect(document.accounts.map(\.id) == [backupID(1), backupID(2)])
    #expect(document.categories.map(\.id) == [backupID(32), backupID(31)])
    #expect(document.transactions.map(\.id) == [backupID(22), backupID(23), backupID(21)])
    #expect(document.checkpoints.map(\.id) == [backupID(10), backupID(11)])
    #expect(document.rawMessages.map(\.id) == [backupID(42), backupID(41)])
    #expect(document.parsingRules.map(\.id) == [backupID(51)])
    #expect(document.categorizationRules.map(\.id) == [backupID(61)])

    #expect(document.accounts[0] == BackupAccount(
        id: backupID(1),
        name: "Everyday",
        institutionName: "Bank",
        sortOrder: 0,
        createdAt: "2026-11-17T11:06:40.000Z",
        archivedAt: nil
    ))
    #expect(document.accounts[1].institutionName == nil)
    #expect(document.categories[1] == BackupCategory(
        id: backupID(31),
        name: "Dining",
        symbolName: "fork.knife",
        colorToken: "coral",
        sortOrder: 1,
        isSystem: false
    ))

    let kfc = try #require(document.transactions.first { $0.id == backupID(23) })
    #expect(kfc.accountID == backupID(1))
    #expect(kfc.amount == "12.5")
    #expect(kfc.direction == .debit)
    #expect(kfc.occurredAt == "2026-11-18T09:06:40.000Z")
    #expect(kfc.recordedAt == "2026-11-18T11:06:10.000Z")
    #expect(kfc.merchantRaw == "KFC")
    #expect(kfc.merchantDisplay == "KFC")
    #expect(kfc.categoryID == backupID(31))
    #expect(kfc.categorySource == .rule)
    #expect(kfc.balanceAfter == "-25.5")
    #expect(kfc.rawMessageID == backupID(41))
    #expect(kfc.parseEngine == .rules)
    #expect(kfc.matchedRuleID == backupID(51))
    #expect(kfc.isTransfer == false)
    #expect(kfc.note == nil)

    let salary = try #require(document.transactions.first { $0.id == backupID(22) })
    #expect(salary.categoryID == backupID(32))
    #expect(salary.categorySource == .manual)
    #expect(salary.balanceAfter == "2474.5")
    #expect(salary.rawMessageID == nil)
    #expect(salary.parseEngine == nil)
    #expect(salary.isTransfer)

    let opening = try #require(document.checkpoints.first { $0.id == backupID(10) })
    #expect(opening.accountID == backupID(1))
    #expect(opening.amount == "1500.25")
    #expect(opening.recordedAt == "2026-11-17T11:06:40.000Z")
    #expect(opening.source == .opening)
    #expect(opening.sourceTransactionID == nil)
    #expect(opening.note == "Opening balance")

    let sms = try #require(document.checkpoints.first { $0.id == backupID(11) })
    #expect(sms.sourceTransactionID == backupID(23))
    #expect(sms.amount == "-25.5")

    #expect(document.rawMessages[1] == BackupRawMessage(
        id: backupID(41),
        text: "MYBANK: RM12.50 spent at KFC",
        sender: "MYBANK",
        receivedAt: "2026-11-18T11:05:40.000Z",
        ingestedAt: "2026-11-18T11:06:10.000Z",
        status: .parsed,
        engine: .rules,
        matchedRuleID: backupID(51),
        errorDescription: nil,
        fingerprint: "fingerprint-kfc"
    ))
    #expect(document.rawMessages[0].status == .ignored)
    #expect(document.rawMessages[0].engine == nil)

    #expect(document.parsingRules[0] == BackupParsingRule(
        id: backupID(51),
        accountID: backupID(1),
        name: "Debit — card",
        direction: .debit,
        pattern: "spent (?<amount>[\\d.]+) at (?<merchant>.+)",
        dateFormat: "dd/MM/yy",
        isCaseInsensitive: true,
        dotMatchesNewlines: false,
        priority: 0,
        isEnabled: true,
        createdAt: "2026-11-17T11:06:40.000Z",
        updatedAt: "2026-11-18T10:06:40.000Z"
    ))
    #expect(document.categorizationRules[0] == BackupCategorizationRule(
        id: backupID(61),
        keyword: "kfc",
        categoryID: backupID(31),
        priority: 0,
        isEnabled: true
    ))

    // The export timestamp is a real ISO-8601 instant with fractional seconds.
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    #expect(formatter.date(from: document.exportedAt) != nil)
}

@Test @MainActor func exportsIdenticalRowsForTheSameStore() throws {
    let context = try makeFixedStore()
    let exporter = BackupExporter(settings: fixtureSettings())

    let first = try exporter.export(context: context, appVersion: "1.4.0")
    let second = try exporter.export(context: context, appVersion: "1.4.0")

    #expect(first.accounts == second.accounts)
    #expect(first.checkpoints == second.checkpoints)
    #expect(first.transactions == second.transactions)
    #expect(first.rawMessages == second.rawMessages)
    #expect(first.parsingRules == second.parsingRules)
    #expect(first.categories == second.categories)
    #expect(first.categorizationRules == second.categorizationRules)
    #expect(first.settings == second.settings)
}

// MARK: - Replace

@Test @MainActor func replaceRestoresASeededExport() throws {
    let store = try makeSeededStore()
    let document = store.document

    try clearStore(store.context)
    #expect(try storeCounts(store.context) == ImportSummary.RowCounts())

    let summary = try BackupImporter().import(
        document: try encodedCopy(of: document),
        into: store.context,
        mode: .replace
    )

    #expect(summary.mode == .replace)
    #expect(summary.created == documentCounts(document))
    #expect(summary.skipped == ImportSummary.RowCounts())
    #expect(try storeCounts(store.context) == documentCounts(document))

    // Accounts.
    let everyday = try #require(try storedRow(Account.self, id: backupID(1), in: store.context, identifying: \.id))
    #expect(everyday.name == "Everyday")
    #expect(everyday.institutionName == "Bank")
    #expect(everyday.sortOrder == 0)
    #expect(everyday.createdAt == storedNow.addingTimeInterval(-86_400))
    #expect(everyday.archivedAt == nil)
    let savings = try #require(try storedRow(Account.self, id: backupID(2), in: store.context, identifying: \.id))
    #expect(savings.name == "Savings")
    #expect(savings.institutionName == nil)
    #expect(savings.archivedAt == storedNow.addingTimeInterval(-3_600))

    // Checkpoints, including the relationship to their account.
    let checkpoint = try #require(
        try storedRow(BalanceCheckpoint.self, id: backupID(10), in: store.context, identifying: \.id)
    )
    #expect(checkpoint.account.id == backupID(1))
    #expect(checkpoint.amount == cents(150_025))
    #expect(checkpoint.recordedAt == storedNow.addingTimeInterval(-86_400))
    #expect(checkpoint.createdAt == storedNow.addingTimeInterval(-86_400))
    #expect(checkpoint.source == .opening)
    #expect(checkpoint.sourceTransactionID == nil)
    #expect(checkpoint.note == "Opening balance")
    let archivedCheckpoint = try #require(
        try storedRow(BalanceCheckpoint.self, id: backupID(11), in: store.context, identifying: \.id)
    )
    #expect(archivedCheckpoint.account.id == backupID(2))
    #expect(archivedCheckpoint.amount == cents(500_000))
    #expect(archivedCheckpoint.source == .manual)
    #expect(archivedCheckpoint.note == nil)

    // Transactions, with their account, category, and raw message resolved by identity.
    let transaction = try #require(
        try storedRow(ZentriCore.Transaction.self, id: backupID(23), in: store.context, identifying: \.id)
    )
    #expect(transaction.account.id == backupID(1))
    #expect(transaction.amount == cents(1_250))
    #expect(transaction.direction == .debit)
    #expect(transaction.occurredAt == storedNow.addingTimeInterval(-7_200))
    #expect(transaction.recordedAt == storedNow.addingTimeInterval(-30))
    #expect(transaction.merchantRaw == "KFC")
    #expect(transaction.merchantDisplay == "KFC")
    #expect(transaction.category?.name == "Dining")
    #expect(transaction.categorySource == .rule)
    #expect(transaction.balanceAfter == cents(-2_550))
    #expect(transaction.parseEngine == .rules)
    #expect(transaction.matchedRuleID == backupID(51))
    #expect(transaction.isTransfer == false)
    #expect(transaction.createdAt == storedNow.addingTimeInterval(-30))
    #expect(transaction.updatedAt == storedNow.addingTimeInterval(-30))

    // Raw messages, including the inverse link back from the message.
    let message = try #require(
        try storedRow(RawMessage.self, id: backupID(41), in: store.context, identifying: \.id)
    )
    #expect(message.text == "MYBANK: RM12.50 spent at KFC")
    #expect(message.sender == "MYBANK")
    #expect(message.receivedAt == storedNow.addingTimeInterval(-60))
    #expect(message.ingestedAt == storedNow.addingTimeInterval(-30))
    #expect(message.status == .parsed)
    #expect(message.engine == .rules)
    #expect(message.errorDescription == nil)
    #expect(message.fingerprint == "fingerprint-kfc")
    #expect(message.transaction?.id == backupID(23))
    #expect(transaction.rawMessage?.id == backupID(41))

    // Parsing rules.
    let rule = try #require(
        try storedRow(ParsingRule.self, id: backupID(51), in: store.context, identifying: \.id)
    )
    #expect(rule.account.id == backupID(1))
    #expect(rule.name == "Debit — card")
    #expect(rule.direction == .debit)
    #expect(rule.pattern == "spent (?<amount>[\\d.]+) at (?<merchant>.+)")
    #expect(rule.dateFormat == "dd/MM/yy")
    #expect(rule.isCaseInsensitive == false)
    #expect(rule.dotMatchesNewlines == true)
    #expect(rule.priority == 2)
    #expect(rule.isEnabled)
    #expect(rule.createdAt == storedNow.addingTimeInterval(-86_400))
    #expect(rule.updatedAt == storedNow.addingTimeInterval(-3_600))

    // The seeded catalog and its keyword rules.
    let categories = try store.context.fetch(FetchDescriptor<ZentriCore.Category>())
    #expect(Set(categories.map(\.name)) == Set([
        "Groceries", "Dining", "Transport", "Shopping", "Bills & Utilities", "Health",
        "Entertainment", "Travel", "Fees & Charges", "Income", "Transfers", "Other",
    ]))
    #expect(categories.allSatisfy { $0.isSystem && !$0.symbolName.isEmpty && !$0.colorToken.isEmpty })
    let categorizationRules = try store.context.fetch(FetchDescriptor<CategorizationRule>())
    #expect(Set(categorizationRules.map(\.keyword)) == ["grab", "uber", "starbucks", "netflix", "amazon"])
    let ruleCategories = Set(categorizationRules.map(\.category.name))
    #expect(ruleCategories == ["Transport", "Dining", "Entertainment", "Shopping"])
    let dining = try #require(document.categories.first { $0.name == "Dining" })
    #expect(try storedRow(ZentriCore.Category.self, id: dining.id, in: store.context, identifying: \.id)?.name == "Dining")

    // Settings travel in the document; the importer leaves them for the settings store to apply.
    #expect(document.settings == BackupSettings(store.settings))
    #expect(try document.settings.makeAppSettings() == store.settings)
}

@Test @MainActor func replaceRemovesRowsTheDocumentDoesNotContain() throws {
    let source = try makeFixedStore()
    let document = try BackupExporter(settings: fixtureSettings()).export(context: source, appVersion: "1.4.0")
    let target = try makeMergeTarget()

    let summary = try BackupImporter().import(document: document, into: target, mode: .replace)

    #expect(summary.created == documentCounts(document))
    #expect(summary.skipped == ImportSummary.RowCounts())
    #expect(try storeCounts(target) == documentCounts(document))

    let everyday = try #require(try storedRow(Account.self, id: backupID(1), in: target, identifying: \.id))
    #expect(everyday.name == "Everyday")
    #expect(everyday.createdAt == storedNow.addingTimeInterval(-86_400))
    #expect(try storedRow(Account.self, id: backupID(98), in: target, identifying: \.id) == nil)
    #expect(try storedRow(RawMessage.self, id: backupID(99), in: target, identifying: \.id) == nil)

    let category = try #require(try storedRow(ZentriCore.Category.self, id: backupID(31), in: target, identifying: \.id))
    #expect(category.name == "Dining")
    #expect(category.colorToken == "coral")
}

@Test @MainActor func replaceRollsBackWhenTheSaveThrows() throws {
    let source = try makeFixedStore()
    let document = try BackupExporter(settings: fixtureSettings()).export(context: source, appVersion: "1.4.0")
    let target = try makeMergeTarget()
    let before = try storeCounts(target)

    var importer = BackupImporter()
    importer.saveHandler = { _ in throw ImportSaveFailure.storeIsUnwritable }

    #expect(throws: ImportSaveFailure.storeIsUnwritable) {
        try importer.import(document: document, into: target, mode: .replace)
    }

    #expect(try storeCounts(target) == before)
    let everyday = try #require(try storedRow(Account.self, id: backupID(1), in: target, identifying: \.id))
    #expect(everyday.name == "Renamed everyday")
    let transaction = try #require(
        try storedRow(ZentriCore.Transaction.self, id: backupID(21), in: target, identifying: \.id)
    )
    #expect(transaction.amount == cents(99_900))
}

// MARK: - Merge

@Test @MainActor func mergeCreatesOnlyMissingRowsAndKeepsExistingOnes() throws {
    let source = try makeFixedStore()
    let document = try BackupExporter(settings: fixtureSettings()).export(context: source, appVersion: "1.4.0")
    let target = try makeMergeTarget()

    let summary = try BackupImporter().import(document: document, into: target, mode: .merge)

    #expect(summary.mode == .merge)
    #expect(summary.created == ImportSummary.RowCounts(
        accounts: 1,
        checkpoints: 1,
        transactions: 2,
        rawMessages: 1,
        parsingRules: 0,
        categories: 1,
        categorizationRules: 1
    ))
    #expect(summary.skipped == ImportSummary.RowCounts(
        accounts: 1,
        checkpoints: 1,
        transactions: 1,
        rawMessages: 1,
        parsingRules: 1,
        categories: 1,
        categorizationRules: 0
    ))
    #expect(try storeCounts(target) == ImportSummary.RowCounts(
        accounts: 3,
        checkpoints: 2,
        transactions: 3,
        rawMessages: 2,
        parsingRules: 1,
        categories: 2,
        categorizationRules: 1
    ))

    // Existing rows keep every value they had.
    let everyday = try #require(try storedRow(Account.self, id: backupID(1), in: target, identifying: \.id))
    #expect(everyday.name == "Renamed everyday")
    #expect(everyday.institutionName == nil)
    let extra = try #require(try storedRow(Account.self, id: backupID(98), in: target, identifying: \.id))
    #expect(extra.name == "Extra")
    let dining = try #require(try storedRow(ZentriCore.Category.self, id: backupID(31), in: target, identifying: \.id))
    #expect(dining.name == "Renamed dining")
    #expect(dining.colorToken == "amber")
    let existingTransaction = try #require(
        try storedRow(ZentriCore.Transaction.self, id: backupID(21), in: target, identifying: \.id)
    )
    #expect(existingTransaction.amount == cents(99_900))
    #expect(existingTransaction.note == "Do not touch")
    let existingCheckpoint = try #require(
        try storedRow(BalanceCheckpoint.self, id: backupID(10), in: target, identifying: \.id)
    )
    #expect(existingCheckpoint.amount == cents(99_900))
    #expect(existingCheckpoint.source == .manual)
    let existingRule = try #require(
        try storedRow(ParsingRule.self, id: backupID(51), in: target, identifying: \.id)
    )
    #expect(existingRule.pattern == "already here")
    let existingMessage = try #require(
        try storedRow(RawMessage.self, id: backupID(99), in: target, identifying: \.id)
    )
    #expect(existingMessage.status == .failed)
    #expect(existingMessage.errorDescription == "The merchant is missing.")

    // Missing rows are created and resolve their relationships by identity.
    let savings = try #require(try storedRow(Account.self, id: backupID(2), in: target, identifying: \.id))
    #expect(savings.name == "Savings")
    let groceries = try #require(try storedRow(ZentriCore.Category.self, id: backupID(32), in: target, identifying: \.id))
    #expect(groceries.name == "Groceries")

    let salary = try #require(
        try storedRow(ZentriCore.Transaction.self, id: backupID(22), in: target, identifying: \.id)
    )
    #expect(salary.account.id == backupID(2))
    #expect(salary.category?.id == backupID(32))
    #expect(salary.categorySource == .manual)
    #expect(salary.amount == cents(250_000))
    #expect(salary.isTransfer)

    let checkpoint = try #require(
        try storedRow(BalanceCheckpoint.self, id: backupID(11), in: target, identifying: \.id)
    )
    #expect(checkpoint.account.id == backupID(2))
    #expect(checkpoint.amount == cents(-2_550))
    #expect(checkpoint.source == .sms)
    #expect(checkpoint.sourceTransactionID == backupID(23))

    let categoryRule = try #require(
        try storedRow(CategorizationRule.self, id: backupID(61), in: target, identifying: \.id)
    )
    #expect(categoryRule.keyword == "kfc")
    #expect(categoryRule.category.id == backupID(31))

    // A message skipped because its fingerprint is already stored still anchors the new transaction:
    // the document's message identity is mapped onto the existing row.
    let kfc = try #require(
        try storedRow(ZentriCore.Transaction.self, id: backupID(23), in: target, identifying: \.id)
    )
    #expect(kfc.account.id == backupID(1))
    #expect(kfc.category?.id == backupID(31))
    #expect(kfc.rawMessage?.id == backupID(99))
    #expect(kfc.amount == cents(1_250))
    #expect(existingMessage.transaction?.id == backupID(23))
    #expect(try storedRow(RawMessage.self, id: backupID(41), in: target, identifying: \.id) == nil)

    let ignored = try #require(try storedRow(RawMessage.self, id: backupID(42), in: target, identifying: \.id))
    #expect(ignored.status == .ignored)
    #expect(ignored.fingerprint == "fingerprint-otp")

    // Settings move through the document only; a merge never writes them.
    #expect(document.settings == BackupSettings(fixtureSettings()))
}

@Test @MainActor func mergeKeepsAStoredMessagesTransactionInPlace() throws {
    let source = try makeFixedStore()
    let document = try BackupExporter(settings: fixtureSettings()).export(context: source, appVersion: "1.4.0")
    let target = try makeAnchoredMessageTarget()

    let summary = try BackupImporter().import(document: document, into: target, mode: .merge)

    // The backup's message 41 is skipped because its fingerprint is message 99's, so its transaction
    // is still created but nothing else of its message is.
    #expect(summary.skipped.rawMessages == 1)
    #expect(summary.created.transactions == 3)
    #expect(try storedRow(RawMessage.self, id: backupID(41), in: target, identifying: \.id) == nil)

    // The stored message keeps the transaction it already belonged to, in both directions.
    let storedMessage = try #require(
        try storedRow(RawMessage.self, id: backupID(99), in: target, identifying: \.id)
    )
    #expect(storedMessage.transaction?.id == backupID(77))
    let existingTransaction = try #require(
        try storedRow(ZentriCore.Transaction.self, id: backupID(77), in: target, identifying: \.id)
    )
    #expect(existingTransaction.rawMessage?.id == backupID(99))

    // Neither the message nor its transaction had a value updated.
    #expect(storedMessage.status == .failed)
    #expect(storedMessage.engine == nil)
    #expect(storedMessage.errorDescription == "The merchant is missing.")
    #expect(storedMessage.ingestedAt == storedNow.addingTimeInterval(-120))
    #expect(existingTransaction.amount == cents(99_900))
    #expect(existingTransaction.merchantDisplay == "Already parsed")
    #expect(existingTransaction.note == "Keep this transaction")

    // The incoming transaction is still created — its identity is new — but without provenance.
    let incoming = try #require(
        try storedRow(ZentriCore.Transaction.self, id: backupID(23), in: target, identifying: \.id)
    )
    #expect(incoming.rawMessage == nil)
    #expect(incoming.account.id == backupID(1))
    #expect(incoming.amount == cents(1_250))
    #expect(incoming.merchantDisplay == "KFC")

    #expect(try storeCounts(target).transactions == 4)
}

@Test @MainActor func mergeRollsBackWhenTheSaveThrows() throws {
    let source = try makeFixedStore()
    let document = try BackupExporter(settings: fixtureSettings()).export(context: source, appVersion: "1.4.0")
    let target = try makeMergeTarget()
    let before = try storeCounts(target)

    var importer = BackupImporter()
    importer.saveHandler = { _ in throw ImportSaveFailure.storeIsUnwritable }

    #expect(throws: ImportSaveFailure.storeIsUnwritable) {
        try importer.import(document: document, into: target, mode: .merge)
    }

    #expect(try storeCounts(target) == before)
    let existingMessage = try #require(
        try storedRow(RawMessage.self, id: backupID(99), in: target, identifying: \.id)
    )
    #expect(existingMessage.transaction == nil)
}

// MARK: - Rejected imports

@Test @MainActor func rejectsAnInvalidImportWithoutChangingTheStore() throws {
    let source = try makeFixedStore()
    var document = try BackupExporter(settings: fixtureSettings()).export(context: source, appVersion: "1.4.0")
    document.transactions[0].categoryID = backupID(99)
    let target = try makeMergeTarget()
    let before = try storeCounts(target)

    for mode in [ImportMode.replace, .merge] {
        let result = Result { try BackupImporter().import(document: document, into: target, mode: mode) }
        guard case .failure(let error) = result else {
            Issue.record("expected \(mode) to reject the document")
            continue
        }
        guard let backupError = error as? BackupError,
              case .brokenReference(let field, let id) = backupError else {
            Issue.record("expected brokenReference in \(mode), got \(error)")
            continue
        }
        #expect(field == "transactions[\(backupID(22).uuidString)].categoryID")
        #expect(id == backupID(99))
        #expect(try storeCounts(target) == before)
    }

    let everyday = try #require(try storedRow(Account.self, id: backupID(1), in: target, identifying: \.id))
    #expect(everyday.name == "Renamed everyday")
}

@Test @MainActor func rejectsADuplicateIDInTheDocument() throws {
    let source = try makeFixedStore()
    var document = try BackupExporter(settings: fixtureSettings()).export(context: source, appVersion: "1.4.0")
    document.accounts.append(document.accounts[0])
    let target = try makeMergeTarget()
    let before = try storeCounts(target)

    #expect(throws: BackupError.duplicateID(backupID(1))) {
        try BackupImporter().import(document: document, into: target, mode: .replace)
    }

    #expect(try storeCounts(target) == before)
}

// MARK: - Saving

@Test @MainActor func savesExactlyOncePerImport() throws {
    let source = try makeFixedStore()
    let document = try BackupExporter(settings: fixtureSettings()).export(context: source, appVersion: "1.4.0")

    for mode in [ImportMode.replace, .merge] {
        let target = try makeMergeTarget()
        var importer = BackupImporter()
        var saves = 0
        importer.saveHandler = { context in
            saves += 1
            try context.save()
        }

        _ = try importer.import(document: document, into: target, mode: mode)

        #expect(saves == 1, "expected one save for \(mode)")
    }
}
