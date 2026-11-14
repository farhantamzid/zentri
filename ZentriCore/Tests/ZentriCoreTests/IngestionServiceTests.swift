import Foundation
import SwiftData
import Testing
@testable import ZentriCore

/// 2026-11-18 11:06:40 UTC.
private let ingestNow = Date(timeIntervalSince1970: 1_795_000_000)

private func utcDate(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0, minute: Int = 0) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
    return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))
        ?? .distantPast
}

/// A money value built exactly from cents, so no test depends on locale or decimal text parsing.
private func cents(_ value: Int) -> Decimal {
    Decimal(sign: value < 0 ? .minus : .plus, exponent: -2, significand: Decimal(abs(value)))
}

private func sampleDraft(
    amount: Decimal = cents(1250),
    direction: Direction = .debit,
    merchant: String = "KFC",
    balanceAfter: Decimal? = nil,
    occurredAt: Date? = utcDate(2026, 11, 17, hour: 9, minute: 30),
    reference: String? = nil,
    categorySuggestion: String? = nil,
    matchedRuleID: UUID? = UUID()
) -> TransactionDraft {
    TransactionDraft(
        direction: direction,
        amount: amount,
        merchant: merchant,
        balanceAfter: balanceAfter,
        occurredAt: occurredAt,
        reference: reference,
        categorySuggestion: categorySuggestion,
        matchedRuleID: matchedRuleID
    )
}

private func sampleRequest(
    text: String = "MYBANK: RM12.50 spent at KFC on 17/11/26",
    sender: String? = "MYBANK",
    receivedAt: Date = ingestNow,
    accountID: UUID? = nil
) -> IngestionRequest {
    IngestionRequest(text: text, sender: sender, receivedAt: receivedAt, accountID: accountID)
}

// MARK: - Test doubles

/// A lock-guarded record of what the service handed to the parser.
///
/// The recorder is shared between the `@MainActor` service and a `Sendable` parser, so its state
/// is guarded by a lock; no test reads it while a parse is in flight.
private final class ParseRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var recordedInputs: [ParseInput] = []
    private var recordedModes: [ParserMode] = []
    private var recordedRules: [[ParsingRuleSpec]] = []

    var inputs: [ParseInput] {
        lock.withLock { recordedInputs }
    }

    var modes: [ParserMode] {
        lock.withLock { recordedModes }
    }

    var ruleIDs: [[UUID]] {
        lock.withLock { recordedRules.map { $0.map(\.id) } }
    }

    func recordInput(_ input: ParseInput) {
        lock.withLock { recordedInputs.append(input) }
    }

    func record(mode: ParserMode, rules: [ParsingRuleSpec]) {
        lock.withLock {
            recordedModes.append(mode)
            recordedRules.append(rules)
        }
    }
}

/// A parser that always returns the same result.
private struct StubParser: TransactionParsing {
    let result: ParseResult
    var recorder: ParseRecorder?

    func parse(_ input: ParseInput) async -> ParseResult {
        recorder?.recordInput(input)
        return result
    }
}

/// A parser that returns a scripted result per call, so one service can see several outcomes.
private final class ScriptedParser: @unchecked Sendable, TransactionParsing {
    private let lock = NSLock()
    private var results: [ParseResult]

    init(_ results: [ParseResult]) {
        self.results = results
    }

    func parse(_ input: ParseInput) async -> ParseResult {
        lock.withLock { results.isEmpty ? .notTransaction : results.removeFirst() }
    }
}

/// A parser that cancels the task it runs in, standing in for a caller that gave up mid-parse.
private struct CancellingParser: TransactionParsing {
    let result: ParseResult

    func parse(_ input: ParseInput) async -> ParseResult {
        withUnsafeCurrentTask { $0?.cancel() }
        return result
    }
}

/// A parser builder that hands back one scripted parser and records what it was asked for.
private struct StubParserBuilder: ParserBuilding {
    let parser: any TransactionParsing
    var recorder: ParseRecorder?

    func makeParser(for mode: ParserMode, rules: [ParsingRuleSpec]) -> any TransactionParsing {
        recorder?.record(mode: mode, rules: rules)
        return parser
    }
}

/// Counts snapshot refreshes so a test can prove ingestion refreshed exactly once.
private actor SpySnapshotRefresher: WidgetSnapshotRefresher {
    private(set) var refreshCount = 0

    func refresh() async {
        refreshCount += 1
    }
}

/// Settings held outside the service, so a test can change them between messages.
@MainActor
private final class SettingsBox {
    var settings: AppSettings

    init(_ settings: AppSettings = .defaultValue) {
        self.settings = settings
    }
}

// MARK: - Fixtures

@MainActor
private struct TestStore {
    let context: ModelContext
    let accounts: [Account]

    func service(
        parser: any TransactionParsing,
        refresher: any WidgetSnapshotRefresher,
        settings: @escaping @MainActor @Sendable () -> AppSettings = { .defaultValue },
        now: Date = ingestNow,
        recorder: ParseRecorder? = nil
    ) -> IngestionService {
        IngestionService(
            context: context,
            settings: settings,
            parserBuilder: StubParserBuilder(parser: parser, recorder: recorder),
            snapshotRefresher: refresher,
            now: { now }
        )
    }
}

@MainActor
private func makeStore(
    accountNames: [String] = ["Everyday"],
    archivedNames: [String] = [],
    seeded: Bool = true
) throws -> TestStore {
    let container = try ZentriContainer.make(inMemory: true)
    let context = ModelContext(container)
    if seeded {
        try SeedData.seed(into: context)
    }
    var accounts: [Account] = []
    for (index, name) in accountNames.enumerated() {
        let account = Account(name: name, institutionName: "Bank", sortOrder: index, createdAt: ingestNow)
        context.insert(account)
        accounts.append(account)
    }
    for (index, name) in archivedNames.enumerated() {
        let account = Account(
            name: name,
            institutionName: "Bank",
            sortOrder: accountNames.count + index,
            createdAt: ingestNow,
            archivedAt: ingestNow
        )
        context.insert(account)
    }
    try context.save()
    return TestStore(context: context, accounts: accounts)
}

@MainActor
@discardableResult
private func insertProcessingMessage(
    in context: ModelContext,
    text: String = "MYBANK: RM12.50 spent at KFC on 17/11/26",
    sender: String? = "MYBANK",
    receivedAt: Date = ingestNow,
    accountID: UUID? = nil
) throws -> RawMessage {
    let message = RawMessage(
        text: text,
        sender: sender,
        receivedAt: receivedAt,
        ingestedAt: receivedAt,
        status: .processing,
        fingerprint: Dedupe.fingerprint(
            text: text, sender: sender, accountID: accountID, receivedAt: receivedAt
        )
    )
    context.insert(message)
    try context.save()
    return message
}

@MainActor
private func fetchTransactions(_ context: ModelContext) throws -> [Transaction] {
    try context.fetch(FetchDescriptor<Transaction>())
}

@MainActor
private func fetchMessages(_ context: ModelContext) throws -> [RawMessage] {
    try context.fetch(FetchDescriptor<RawMessage>())
}

@MainActor
private func fetchCheckpoints(_ context: ModelContext) throws -> [BalanceCheckpoint] {
    try context.fetch(FetchDescriptor<BalanceCheckpoint>())
}

// MARK: - Success

@Test @MainActor func ingestPersistsParsedMessageTransactionAndCheckpoint() async throws {
    let store = try makeStore()
    let refresher = SpySnapshotRefresher()
    let ruleID = UUID()
    let parser = StubParser(result: .transaction(sampleDraft(balanceAfter: cents(123_450), matchedRuleID: ruleID)))
    let service = store.service(parser: parser, refresher: refresher)
    let request = sampleRequest(accountID: store.accounts[0].id)

    let outcome = await service.ingest(request)

    let transaction = try #require(try fetchTransactions(store.context).first)
    #expect(outcome == .transaction(transaction.id))
    #expect(await refresher.refreshCount == 1)

    let message = try #require(transaction.rawMessage)
    #expect(message.status == .parsed)
    #expect(message.text == request.text)
    #expect(message.sender == "MYBANK")
    #expect(message.receivedAt == request.receivedAt)
    #expect(message.ingestedAt == ingestNow)
    #expect(message.engine == .rules)
    #expect(message.matchedRuleID == ruleID)
    #expect(message.errorDescription == nil)
    #expect(message.fingerprint == Dedupe.fingerprint(
        text: request.text, sender: request.sender, accountID: store.accounts[0].id, receivedAt: request.receivedAt
    ))
    #expect(try store.context.fetchCount(FetchDescriptor<RawMessage>()) == 1)

    #expect(transaction.account.id == store.accounts[0].id)
    #expect(transaction.amount == cents(1250))
    #expect(transaction.direction == .debit)
    #expect(transaction.occurredAt == utcDate(2026, 11, 17, hour: 9, minute: 30))
    #expect(transaction.recordedAt == ingestNow)
    #expect(transaction.merchantRaw == "KFC")
    #expect(transaction.merchantDisplay == "KFC")
    #expect(transaction.balanceAfter == cents(123_450))
    #expect(transaction.parseEngine == .rules)
    #expect(transaction.matchedRuleID == ruleID)
    #expect(transaction.createdAt == ingestNow)
    #expect(transaction.updatedAt == ingestNow)
    #expect(transaction.category?.name == "Other")
    #expect(transaction.categorySource == .default)

    let checkpoint = try #require(try fetchCheckpoints(store.context).first)
    #expect(checkpoint.amount == cents(123_450))
    #expect(checkpoint.recordedAt == ingestNow)
    #expect(checkpoint.createdAt == ingestNow)
    #expect(checkpoint.source == .sms)
    #expect(checkpoint.sourceTransactionID == transaction.id)
    #expect(checkpoint.account.id == store.accounts[0].id)
}

@Test @MainActor func ingestRecordsTheEngineThatProducedTheDraft() async throws {
    let store = try makeStore()
    let service = store.service(
        parser: StubParser(result: .transaction(sampleDraft(matchedRuleID: nil))),
        refresher: SpySnapshotRefresher()
    )

    _ = await service.ingest(sampleRequest())

    let transaction = try #require(try fetchTransactions(store.context).first)
    #expect(transaction.parseEngine == .foundationModels)
    #expect(transaction.matchedRuleID == nil)
    #expect(transaction.rawMessage?.engine == .foundationModels)
}

@Test @MainActor func ingestWithoutABalanceCreatesNoCheckpoint() async throws {
    let store = try makeStore()
    let service = store.service(
        parser: StubParser(result: .transaction(sampleDraft(balanceAfter: nil))),
        refresher: SpySnapshotRefresher()
    )

    _ = await service.ingest(sampleRequest())

    let transaction = try #require(try fetchTransactions(store.context).first)
    #expect(transaction.balanceAfter == nil)
    #expect(try fetchCheckpoints(store.context).isEmpty)
}

@Test @MainActor func ingestFeedsNormalizedTextToTheParserAndStoresTheOriginal() async throws {
    let store = try makeStore()
    let recorder = ParseRecorder()
    let service = store.service(
        parser: StubParser(result: .transaction(sampleDraft()), recorder: recorder),
        refresher: SpySnapshotRefresher(),
        recorder: recorder
    )
    let original = "\r\n  RM12.50   spent at KFC\r\non 17/11/26  \r\n"

    _ = await service.ingest(sampleRequest(text: original))

    let input = try #require(recorder.inputs.first)
    #expect(input.text == "RM12.50   spent at KFC\non 17/11/26")
    #expect(input.accountID == store.accounts[0].id)
    #expect(input.sender == "MYBANK")
    #expect(input.receivedAt == ingestNow)
    let message = try #require(try fetchMessages(store.context).first)
    #expect(message.text == original)
}

// MARK: - Merchant sanitization

@Test @MainActor func ingestStripsTrailingMerchantNoise() async throws {
    let cases: [(extracted: String, raw: String, display: String)] = [
        ("Coffee Bean  Ref 12345", "Coffee Bean Ref 12345", "Coffee Bean"),
        ("KFC on 17/11/26", "KFC on 17/11/26", "KFC"),
        ("KFC on 17 Nov 2026", "KFC on 17 Nov 2026", "KFC"),
        ("KFC Ref: 8891-A", "KFC Ref: 8891-A", "KFC"),
        ("KFC on 17/11/26 Ref 8891", "KFC on 17/11/26 Ref 8891", "KFC"),
        ("Grab Ride", "Grab Ride", "Grab Ride"),
        ("Ref 998877", "Ref 998877", "Unknown merchant"),
    ]

    for item in cases {
        let store = try makeStore()
        let service = store.service(
            parser: StubParser(result: .transaction(sampleDraft(merchant: item.extracted))),
            refresher: SpySnapshotRefresher()
        )

        _ = await service.ingest(sampleRequest())

        let transaction = try #require(try fetchTransactions(store.context).first)
        #expect(transaction.merchantRaw == item.raw, "raw merchant for \(item.extracted)")
        #expect(transaction.merchantDisplay == item.display, "display merchant for \(item.extracted)")
    }
}

// MARK: - Categorization

@Test @MainActor func ingestAppliesAKeywordRule() async throws {
    let store = try makeStore()
    let service = store.service(
        parser: StubParser(result: .transaction(sampleDraft(merchant: "GRAB Ride"))),
        refresher: SpySnapshotRefresher()
    )

    _ = await service.ingest(sampleRequest())

    let transaction = try #require(try fetchTransactions(store.context).first)
    #expect(transaction.category?.name == "Transport")
    #expect(transaction.categorySource == .rule)
    #expect(try store.context.fetchCount(FetchDescriptor<ZentriCore.Category>()) == 12)
}

@Test @MainActor func ingestUsesTheEngineSuggestionWhenNoRuleMatches() async throws {
    let store = try makeStore()
    let service = store.service(
        parser: StubParser(result: .transaction(sampleDraft(merchant: "Kopi Corner", categorySuggestion: "Dining"))),
        refresher: SpySnapshotRefresher()
    )

    _ = await service.ingest(sampleRequest())

    let transaction = try #require(try fetchTransactions(store.context).first)
    #expect(transaction.category?.name == "Dining")
    #expect(transaction.categorySource == .ai)
}

@Test @MainActor func ingestFallsBackToOtherWithoutCreatingACategory() async throws {
    let store = try makeStore()
    let service = store.service(
        parser: StubParser(result: .transaction(sampleDraft(merchant: "Kopi Corner", categorySuggestion: "Spaceships"))),
        refresher: SpySnapshotRefresher()
    )

    _ = await service.ingest(sampleRequest())

    let transaction = try #require(try fetchTransactions(store.context).first)
    #expect(transaction.category?.name == "Other")
    #expect(transaction.categorySource == .default)
    #expect(try store.context.fetchCount(FetchDescriptor<ZentriCore.Category>()) == 12)
}

@Test @MainActor func ingestCategorizesAgainstTheLiveCatalog() async throws {
    let store = try makeStore()
    let categories = try store.context.fetch(FetchDescriptor<ZentriCore.Category>())
    let groceries = try #require(categories.first { $0.name == "Groceries" })
    store.context.insert(CategorizationRule(keyword: "market", category: groceries, priority: 0, isEnabled: true))
    try store.context.save()
    let service = store.service(
        parser: StubParser(result: .transaction(sampleDraft(merchant: "Corner Market"))),
        refresher: SpySnapshotRefresher()
    )

    _ = await service.ingest(sampleRequest())

    let transaction = try #require(try fetchTransactions(store.context).first)
    #expect(transaction.category?.name == "Groceries")
    #expect(transaction.categorySource == .rule)
}

// MARK: - Duplicates

@Test @MainActor func ingestRecordsAnExactDuplicateWithoutATransaction() async throws {
    let store = try makeStore()
    let refresher = SpySnapshotRefresher()
    let service = store.service(
        parser: StubParser(result: .transaction(sampleDraft(balanceAfter: cents(100_000)))),
        refresher: refresher
    )
    let request = sampleRequest()

    let first = await service.ingest(request)
    let second = await service.ingest(request)

    #expect(first != .duplicate)
    #expect(second == .duplicate)
    #expect(try store.context.fetchCount(FetchDescriptor<Transaction>()) == 1)
    #expect(try store.context.fetchCount(FetchDescriptor<BalanceCheckpoint>()) == 1)
    let messages = try fetchMessages(store.context)
    #expect(messages.count == 2)
    #expect(Set(messages.map(\.status)) == [.parsed, .duplicate])
    let duplicate = try #require(messages.first { $0.status == .duplicate })
    #expect(duplicate.transaction == nil)
    #expect(duplicate.fingerprint == Dedupe.fingerprint(
        text: request.text, sender: request.sender, accountID: store.accounts[0].id, receivedAt: request.receivedAt
    ))
    #expect(await refresher.refreshCount == 2)
}

@Test @MainActor func ingestRecordsADuplicateInsideTheWindowEvenInAnotherMinute() async throws {
    let store = try makeStore()
    let service = store.service(
        parser: StubParser(result: .transaction(sampleDraft())),
        refresher: SpySnapshotRefresher()
    )
    let base = Date(timeIntervalSince1970: 1_790_000_030)

    let first = await service.ingest(sampleRequest(receivedAt: base))
    let second = await service.ingest(sampleRequest(receivedAt: base.addingTimeInterval(31)))

    #expect(first != .duplicate)
    #expect(second == .duplicate)
    #expect(try store.context.fetchCount(FetchDescriptor<Transaction>()) == 1)
}

@Test @MainActor func ingestTreatsAnotherSenderAsANewMessage() async throws {
    let store = try makeStore()
    let service = store.service(
        parser: StubParser(result: .transaction(sampleDraft())),
        refresher: SpySnapshotRefresher()
    )

    let first = await service.ingest(sampleRequest(sender: "MYBANK"))
    let second = await service.ingest(sampleRequest(sender: "OTHERBANK"))

    #expect(first != .duplicate)
    #expect(second != .duplicate)
    #expect(try store.context.fetchCount(FetchDescriptor<Transaction>()) == 2)
}

// MARK: - Not a transaction and failures

@Test @MainActor func ingestStoresANotTransactionAsIgnored() async throws {
    let store = try makeStore()
    let refresher = SpySnapshotRefresher()
    let service = store.service(parser: StubParser(result: .notTransaction), refresher: refresher)

    let outcome = await service.ingest(sampleRequest())

    #expect(outcome == .notTransaction)
    let message = try #require(try fetchMessages(store.context).first)
    #expect(message.status == .ignored)
    #expect(message.transaction == nil)
    #expect(message.engine == nil)
    #expect(message.errorDescription == nil)
    #expect(try fetchTransactions(store.context).isEmpty)
    #expect(await refresher.refreshCount == 1)
}

@Test @MainActor func ingestStoresAParseFailureWithItsDiagnostics() async throws {
    let store = try makeStore()
    let refresher = SpySnapshotRefresher()
    let diagnostic = ParseDiagnostic(
        code: .missingAmountGroup,
        ruleID: UUID(),
        field: "amount",
        message: "The rule pattern has no 'amount' capture group."
    )
    let service = store.service(parser: StubParser(result: .failure([diagnostic])), refresher: refresher)

    let outcome = await service.ingest(sampleRequest())

    #expect(outcome == .failed([diagnostic]))
    let message = try #require(try fetchMessages(store.context).first)
    #expect(message.status == .failed)
    #expect(message.errorDescription == diagnostic.message)
    #expect(message.transaction == nil)
    #expect(try fetchTransactions(store.context).isEmpty)
    #expect(try fetchCheckpoints(store.context).isEmpty)
    #expect(await refresher.refreshCount == 1)
}

@Test @MainActor func ingestFailureLeavesNoPartialTransactionOrCheckpoint() async throws {
    let store = try makeStore()
    let diagnostic = ParseDiagnostic(code: .missingMerchant, field: "merchant", message: "The merchant is missing.")
    let service = store.service(
        parser: StubParser(result: .failure([diagnostic])),
        refresher: SpySnapshotRefresher()
    )

    _ = await service.ingest(sampleRequest())

    #expect(try store.context.fetchCount(FetchDescriptor<Transaction>()) == 0)
    #expect(try store.context.fetchCount(FetchDescriptor<BalanceCheckpoint>()) == 0)
    #expect(try store.context.fetchCount(FetchDescriptor<RawMessage>()) == 1)
}

@Test @MainActor func ingestKeepsACancelledParseRetryable() async throws {
    let store = try makeStore()
    let cancelled = ParseDiagnostic(code: .cancelled, field: "model", message: "Parsing was cancelled.")
    let other = ParseDiagnostic(code: .modelFailed, field: "model", message: "The on-device model could not read this message.")
    let service = store.service(
        parser: StubParser(result: .failure([other, cancelled])),
        refresher: SpySnapshotRefresher()
    )

    let outcome = await service.ingest(sampleRequest())

    #expect(outcome == .failed([other, cancelled]))
    let message = try #require(try fetchMessages(store.context).first)
    #expect(message.status == .processing)
    #expect(message.errorDescription == nil)
    #expect(try fetchTransactions(store.context).isEmpty)
}

@Test @MainActor func ingestKeepsAFinishedParseRetryableWhenTheTaskWasCancelled() async throws {
    let store = try makeStore()
    let service = store.service(
        parser: CancellingParser(result: .transaction(sampleDraft())),
        refresher: SpySnapshotRefresher()
    )

    let outcome = await Task { @MainActor in await service.ingest(sampleRequest()) }.value

    let expected = ParseDiagnostic(code: .cancelled, message: "Parsing was cancelled.")
    #expect(outcome == .failed([expected]))
    let message = try #require(try fetchMessages(store.context).first)
    #expect(message.status == .processing)
    #expect(try fetchTransactions(store.context).isEmpty)
}

// MARK: - Account resolution

@Test @MainActor func ingestUsesTheOnlyActiveAccount() async throws {
    let store = try makeStore()
    let service = store.service(
        parser: StubParser(result: .transaction(sampleDraft())),
        refresher: SpySnapshotRefresher()
    )

    _ = await service.ingest(sampleRequest())

    let transaction = try #require(try fetchTransactions(store.context).first)
    #expect(transaction.account.id == store.accounts[0].id)
}

@Test @MainActor func ingestUsesTheRequestedAccountAmongSeveral() async throws {
    let store = try makeStore(accountNames: ["Everyday", "Savings"])
    let service = store.service(
        parser: StubParser(result: .transaction(sampleDraft())),
        refresher: SpySnapshotRefresher()
    )

    _ = await service.ingest(sampleRequest(accountID: store.accounts[1].id))

    let transaction = try #require(try fetchTransactions(store.context).first)
    #expect(transaction.account.id == store.accounts[1].id)
}

@Test @MainActor func ingestFailsWithoutAChosenAccountWhenSeveralAreActive() async throws {
    let store = try makeStore(accountNames: ["Everyday", "Savings"])
    let refresher = SpySnapshotRefresher()
    let service = store.service(
        parser: StubParser(result: .transaction(sampleDraft())),
        refresher: refresher
    )

    let outcome = await service.ingest(sampleRequest())

    let expected = ParseDiagnostic(
        code: .missingField,
        field: "account",
        message: "Choose an account in the Shortcut."
    )
    #expect(outcome == .failed([expected]))
    let message = try #require(try fetchMessages(store.context).first)
    #expect(message.status == .failed)
    #expect(message.errorDescription == expected.message)
    #expect(try fetchTransactions(store.context).isEmpty)
    #expect(await refresher.refreshCount == 1)
}

@Test @MainActor func ingestFailsWhenNoAccountExists() async throws {
    let store = try makeStore(accountNames: [])
    let service = store.service(
        parser: StubParser(result: .transaction(sampleDraft())),
        refresher: SpySnapshotRefresher()
    )

    let outcome = await service.ingest(sampleRequest())

    let expected = ParseDiagnostic(
        code: .missingField,
        field: "account",
        message: "Add an account in Zentri before capturing messages."
    )
    #expect(outcome == .failed([expected]))
    #expect(try store.context.fetchCount(FetchDescriptor<RawMessage>()) == 1)
}

@Test @MainActor func ingestIgnoresAnArchivedAccountWhenResolving() async throws {
    let store = try makeStore(accountNames: ["Everyday"], archivedNames: ["Old Account"])
    let service = store.service(
        parser: StubParser(result: .transaction(sampleDraft())),
        refresher: SpySnapshotRefresher()
    )

    _ = await service.ingest(sampleRequest())

    let transaction = try #require(try fetchTransactions(store.context).first)
    #expect(transaction.account.id == store.accounts[0].id)
}

// MARK: - Rules and settings

@Test @MainActor func ingestOrdersRulesByPriorityThenCreationDate() async throws {
    let store = try makeStore()
    let account = store.accounts[0]
    let later = ParsingRule(
        account: account, name: "Later", direction: .debit, pattern: "spent", priority: 5,
        isEnabled: true, createdAt: utcDate(2026, 1, 2), updatedAt: utcDate(2026, 1, 2)
    )
    let earlier = ParsingRule(
        account: account, name: "Earlier", direction: .debit, pattern: "spent", priority: 5,
        isEnabled: true, createdAt: utcDate(2026, 1, 1), updatedAt: utcDate(2026, 1, 1)
    )
    let first = ParsingRule(
        account: account, name: "First", direction: .debit, pattern: "spent", priority: 1,
        isEnabled: true, createdAt: utcDate(2026, 1, 3), updatedAt: utcDate(2026, 1, 3)
    )
    // Inserted in the opposite order to the expected result, so insertion order cannot pass the test.
    store.context.insert(later)
    store.context.insert(earlier)
    store.context.insert(first)
    try store.context.save()
    let recorder = ParseRecorder()
    let service = store.service(
        parser: StubParser(result: .transaction(sampleDraft())),
        refresher: SpySnapshotRefresher(),
        recorder: recorder
    )

    _ = await service.ingest(sampleRequest())

    #expect(recorder.ruleIDs.first == [first.id, earlier.id, later.id])
}

@Test @MainActor func ingestReadsTheSettingsForEachMessage() async throws {
    let store = try makeStore()
    let box = SettingsBox(AppSettings(parserMode: .rules))
    let recorder = ParseRecorder()
    let service = store.service(
        parser: StubParser(result: .notTransaction),
        refresher: SpySnapshotRefresher(),
        settings: { box.settings },
        recorder: recorder
    )

    _ = await service.ingest(sampleRequest(text: "first message"))
    box.settings.parserMode = .foundationModels
    _ = await service.ingest(sampleRequest(text: "second message"))

    #expect(recorder.modes == [.rules, .foundationModels])
}

// MARK: - Refresh cadence

@Test @MainActor func ingestRefreshesTheSnapshotOnceForEveryOutcome() async throws {
    let store = try makeStore()
    let refresher = SpySnapshotRefresher()
    let diagnostic = ParseDiagnostic(code: .invalidAmount, field: "amount", message: "The captured amount is not a number.")
    let parser = ScriptedParser([
        .transaction(sampleDraft()),
        .notTransaction,
        .failure([diagnostic]),
    ])
    let service = store.service(parser: parser, refresher: refresher)
    let repeatableText = "Your one-time password is 123456"

    let success = await service.ingest(sampleRequest(text: "RM12.50 spent at KFC"))
    let ignored = await service.ingest(sampleRequest(text: repeatableText))
    let failed = await service.ingest(sampleRequest(text: "RM9.00 spent at Toast"))
    // The same text arrives again, so the pipeline stops at dedupe and never reaches the parser.
    let duplicate = await service.ingest(sampleRequest(text: repeatableText))

    if case .transaction = success {} else { Issue.record("expected the first message to be a transaction") }
    #expect(ignored == .notTransaction)
    #expect(failed == .failed([diagnostic]))
    #expect(duplicate == .duplicate)
    #expect(await refresher.refreshCount == 4)
}

@Test @MainActor func ingestRetriesAMessageWhoseLastAttemptFailed() async throws {
    let store = try makeStore()
    let diagnostic = ParseDiagnostic(code: .missingMerchant, field: "merchant", message: "The merchant is missing.")
    let parser = ScriptedParser([.failure([diagnostic]), .transaction(sampleDraft())])
    let service = store.service(parser: parser, refresher: SpySnapshotRefresher())
    let request = sampleRequest()

    let first = await service.ingest(request)
    let second = await service.ingest(request)

    #expect(first == .failed([diagnostic]))
    #expect(second != .duplicate)
    #expect(try store.context.fetchCount(FetchDescriptor<Transaction>()) == 1)
    #expect(try store.context.fetchCount(FetchDescriptor<RawMessage>()) == 2)
}

// MARK: - Retry

@Test @MainActor func retryPendingReusesTheExistingRawMessage() async throws {
    let store = try makeStore()
    let refresher = SpySnapshotRefresher()
    let message = try insertProcessingMessage(in: store.context, accountID: store.accounts[0].id)
    let service = store.service(
        parser: StubParser(result: .transaction(sampleDraft(balanceAfter: cents(90_000)))),
        refresher: refresher
    )

    let outcomes = await service.retryPending()

    let transaction = try #require(try fetchTransactions(store.context).first)
    #expect(outcomes == [.transaction(transaction.id)])
    #expect(try store.context.fetchCount(FetchDescriptor<RawMessage>()) == 1)
    #expect(message.status == .parsed)
    #expect(message.transaction?.id == transaction.id)
    #expect(message.ingestedAt == ingestNow)
    #expect(transaction.account.id == store.accounts[0].id)
    #expect(transaction.rawMessage?.id == message.id)
    #expect(try store.context.fetchCount(FetchDescriptor<BalanceCheckpoint>()) == 1)
    #expect(await refresher.refreshCount == 1)
}

@Test @MainActor func retryPendingLeavesTheMessageFailedWhenParsingStillFails() async throws {
    let store = try makeStore()
    let message = try insertProcessingMessage(in: store.context)
    let diagnostic = ParseDiagnostic(code: .missingMerchant, field: "merchant", message: "The merchant is missing.")
    let service = store.service(
        parser: StubParser(result: .failure([diagnostic])),
        refresher: SpySnapshotRefresher()
    )

    let outcomes = await service.retryPending()

    #expect(outcomes == [.failed([diagnostic])])
    #expect(message.status == .failed)
    #expect(message.errorDescription == diagnostic.message)
    #expect(try fetchTransactions(store.context).isEmpty)
}

@Test @MainActor func retryPendingLeavesTheMessageProcessingWhenCancelled() async throws {
    let store = try makeStore()
    let message = try insertProcessingMessage(in: store.context)
    let cancelled = ParseDiagnostic(code: .cancelled, field: "model", message: "Parsing was cancelled.")
    let service = store.service(
        parser: StubParser(result: .failure([cancelled])),
        refresher: SpySnapshotRefresher()
    )

    let outcomes = await service.retryPending()

    #expect(outcomes == [.failed([cancelled])])
    #expect(message.status == .processing)
    #expect(message.errorDescription == nil)
}

@Test @MainActor func retryPendingUsesTheMatchedRulesAccount() async throws {
    let store = try makeStore(accountNames: ["Everyday", "Savings"])
    let savings = store.accounts[1]
    let rule = ParsingRule(
        account: savings, name: "Savings debit", direction: .debit, pattern: "spent", priority: 0,
        isEnabled: true, createdAt: ingestNow, updatedAt: ingestNow
    )
    store.context.insert(rule)
    try store.context.save()
    let message = try insertProcessingMessage(in: store.context)
    let service = store.service(
        parser: StubParser(result: .transaction(sampleDraft(matchedRuleID: rule.id))),
        refresher: SpySnapshotRefresher()
    )

    let outcomes = await service.retryPending()

    let transaction = try #require(try fetchTransactions(store.context).first)
    #expect(outcomes == [.transaction(transaction.id)])
    #expect(transaction.account.id == savings.id)
    #expect(transaction.parseEngine == .rules)
    #expect(message.matchedRuleID == rule.id)
}

@Test @MainActor func retryPendingWithoutAnAccountKeepsTheMessageRetryable() async throws {
    let store = try makeStore(accountNames: [])
    let message = try insertProcessingMessage(in: store.context)
    let service = store.service(
        parser: StubParser(result: .transaction(sampleDraft(matchedRuleID: nil))),
        refresher: SpySnapshotRefresher()
    )

    let outcomes = await service.retryPending()

    let expected = ParseDiagnostic(
        code: .missingField,
        field: "account",
        message: "Choose an account for this message."
    )
    #expect(outcomes == [.failed([expected])])
    #expect(message.status == .processing)
    #expect(try fetchTransactions(store.context).isEmpty)
}

@Test @MainActor func retryPendingProcessesMessagesInReceivedAtOrder() async throws {
    let store = try makeStore()
    let earlier = try insertProcessingMessage(
        in: store.context, text: "earlier message", receivedAt: ingestNow.addingTimeInterval(-600)
    )
    let later = try insertProcessingMessage(
        in: store.context, text: "later message", receivedAt: ingestNow
    )
    let diagnostic = ParseDiagnostic(code: .invalidAmount, field: "amount", message: "The captured amount is not a number.")
    let parser = ScriptedParser([.transaction(sampleDraft()), .failure([diagnostic])])
    let service = store.service(parser: parser, refresher: SpySnapshotRefresher())

    let outcomes = await service.retryPending()

    #expect(outcomes.count == 2)
    if case .transaction = outcomes.first {} else { Issue.record("expected the earlier message first") }
    #expect(outcomes.last == .failed([diagnostic]))
    #expect(earlier.status == .parsed)
    #expect(later.status == .failed)
}

@Test @MainActor func retryPendingRefreshesTheSnapshotOncePerMessage() async throws {
    let store = try makeStore()
    try insertProcessingMessage(in: store.context, text: "first message")
    try insertProcessingMessage(in: store.context, text: "second message", receivedAt: ingestNow.addingTimeInterval(60))
    let refresher = SpySnapshotRefresher()
    let service = store.service(parser: StubParser(result: .notTransaction), refresher: refresher)

    let outcomes = await service.retryPending()

    #expect(outcomes == [.notTransaction, .notTransaction])
    #expect(await refresher.refreshCount == 2)
}

@Test @MainActor func retryPendingMarksAnAlreadyIngestedMessageAsDuplicate() async throws {
    let store = try makeStore()
    let service = store.service(
        parser: StubParser(result: .transaction(sampleDraft())),
        refresher: SpySnapshotRefresher()
    )
    let request = sampleRequest()
    _ = await service.ingest(request)
    let pending = try insertProcessingMessage(in: store.context, accountID: store.accounts[0].id)

    let outcomes = await service.retryPending()

    #expect(outcomes == [.duplicate])
    #expect(pending.status == .duplicate)
    #expect(pending.transaction == nil)
    #expect(try store.context.fetchCount(FetchDescriptor<Transaction>()) == 1)
}

@Test @MainActor func retryPendingLeavesFailedMessagesAlone() async throws {
    let store = try makeStore()
    let failed = RawMessage(
        text: "MYBANK: RM12.50 spent at KFC",
        sender: "MYBANK",
        receivedAt: ingestNow,
        ingestedAt: ingestNow,
        status: .failed,
        errorDescription: "The merchant is missing.",
        fingerprint: "already-failed"
    )
    store.context.insert(failed)
    try store.context.save()
    let refresher = SpySnapshotRefresher()
    let service = store.service(
        parser: StubParser(result: .transaction(sampleDraft())),
        refresher: refresher
    )

    let outcomes = await service.retryPending()

    #expect(outcomes.isEmpty)
    #expect(failed.status == .failed)
    #expect(try store.context.fetchCount(FetchDescriptor<Transaction>()) == 0)
    #expect(await refresher.refreshCount == 0)
}
