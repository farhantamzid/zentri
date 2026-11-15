import Foundation
import SwiftData
import Testing
@testable import ZentriCore

/// 2026-11-18 11:06:40 UTC: the instant the reprocessor treats as now.
private let reprocessNow = Date(timeIntervalSince1970: 1_795_000_000)
/// When the archived messages arrived and were first ingested, an hour earlier.
private let receivedEarlier = reprocessNow.addingTimeInterval(-3_600)

private let balanceText = "MYBANK: RM12.50 spent at KFC Avl Bal RM1,234.50"
private let balancePattern = #"RM(?<amount>[\d.,]+) spent at (?<merchant>.+?) Avl Bal RM(?<balance>[\d.,]+)"#
private let noBalancePattern = #"RM(?<amount>[\d.,]+) spent at (?<merchant>.+?) Avl"#

/// Counts snapshot refreshes so a test can prove the widgets were refreshed.
private actor CountingRefresher: WidgetSnapshotRefresher {
    private(set) var refreshCount = 0

    func refresh() async {
        refreshCount += 1
    }
}

/// A stand-in parser builder whose parser cancels the task it runs in.
private struct CancellingParserBuilder: ParserBuilding {
    func makeParser(for mode: ParserMode, rules: [ParsingRuleSpec]) -> any TransactionParsing {
        CancellingParser()
    }
}

private struct CancellingParser: TransactionParsing {
    func parse(_ input: ParseInput) async -> ParseResult {
        withUnsafeCurrentTask { $0?.cancel() }
        return .notTransaction
    }
}

/// A parser builder whose parser always answers with the same result.
private struct ScriptedParserBuilder: ParserBuilding {
    let result: ParseResult

    func makeParser(for mode: ParserMode, rules: [ParsingRuleSpec]) -> any TransactionParsing {
        ScriptedParser(result: result)
    }
}

private struct ScriptedParser: TransactionParsing {
    let result: ParseResult

    func parse(_ input: ParseInput) async -> ParseResult {
        result
    }
}

/// Holds the container for as long as a test uses its context.
@MainActor
private struct Store {
    let container: ModelContainer
    let account: Account
    var context: ModelContext { container.mainContext }

    func transactions() throws -> [ZentriCore.Transaction] {
        try context.fetch(FetchDescriptor<ZentriCore.Transaction>())
    }

    func messages() throws -> [RawMessage] {
        try context.fetch(FetchDescriptor<RawMessage>())
    }

    func smsCheckpoints() throws -> [BalanceCheckpoint] {
        try context.fetch(FetchDescriptor<BalanceCheckpoint>()).filter { $0.source == .sms }
    }

    func category(named name: String) throws -> ZentriCore.Category {
        try #require(try context.fetch(FetchDescriptor<ZentriCore.Category>()).first { $0.name == name })
    }

    /// Adds a rule and returns the stored rules as the engine sees them.
    @discardableResult
    func addRule(pattern: String = balancePattern, account: Account? = nil) throws -> [ParsingRuleSpec] {
        context.insert(ParsingRule(
            account: account ?? self.account,
            name: "Debit",
            direction: .debit,
            pattern: pattern,
            priority: 0,
            isEnabled: true,
            createdAt: receivedEarlier,
            updatedAt: receivedEarlier
        ))
        try context.save()
        return try StoredParsingRules.specs(in: context)
    }

    func addAccount(_ name: String, sortOrder: Int) throws -> Account {
        let account = Account(name: name, sortOrder: sortOrder, createdAt: receivedEarlier)
        context.insert(account)
        try context.save()
        return account
    }

    /// Archives a message with the given status.
    func addMessage(
        _ text: String = balanceText,
        status: ParseStatus = .failed,
        fingerprint: String = "fingerprint-1",
        receivedAt: Date = receivedEarlier
    ) throws -> RawMessage {
        let message = RawMessage(
            text: text,
            sender: "MYBANK",
            receivedAt: receivedAt,
            ingestedAt: receivedAt,
            status: status,
            errorDescription: status == .failed ? "The message could not be read." : nil,
            fingerprint: fingerprint
        )
        context.insert(message)
        try context.save()
        return message
    }

    /// Archives a parsed message with its transaction and, when given, an SMS checkpoint.
    func addParsed(
        balance: Decimal?,
        category: ZentriCore.Category? = nil,
        categorySource: CategorySource? = nil
    ) throws -> (RawMessage, ZentriCore.Transaction) {
        let message = try addMessage(status: .parsed)
        message.engine = .rules
        let transaction = ZentriCore.Transaction(
            account: account,
            amount: 99,
            direction: .credit,
            occurredAt: receivedEarlier,
            recordedAt: receivedEarlier,
            merchantRaw: "Old merchant",
            merchantDisplay: "Old merchant",
            category: category,
            categorySource: categorySource,
            balanceAfter: balance,
            rawMessage: message,
            parseEngine: .rules,
            isTransfer: true,
            note: "Lunch with Sam",
            createdAt: receivedEarlier,
            updatedAt: receivedEarlier
        )
        context.insert(transaction)
        if let balance {
            context.insert(BalanceCheckpoint(
                account: account,
                amount: balance,
                recordedAt: receivedEarlier,
                source: .sms,
                sourceTransactionID: transaction.id,
                createdAt: receivedEarlier
            ))
        }
        try context.save()
        return (message, transaction)
    }
}

/// A seeded store with one account opened two hours ago.
@MainActor
private func makeStore() throws -> Store {
    let container = try ZentriContainer.make(inMemory: true)
    let context = container.mainContext
    try SeedData.seed(into: context)
    let account = Account(name: "Everyday", sortOrder: 0, createdAt: receivedEarlier)
    context.insert(account)
    context.insert(BalanceCheckpoint(
        account: account,
        amount: 1_000,
        recordedAt: receivedEarlier.addingTimeInterval(-3_600),
        source: .opening,
        createdAt: receivedEarlier.addingTimeInterval(-3_600)
    ))
    try context.save()
    return Store(container: container, account: account)
}

@MainActor
private func makeReprocessor(
    _ store: Store,
    refresher: CountingRefresher = CountingRefresher(),
    builder: (any ParserBuilding)? = nil
) -> RawMessageReprocessor {
    RawMessageReprocessor(
        context: store.context,
        parserBuilder: builder ?? ParserFactory(modelClient: StubModelClient(
            availabilityValue: .unavailable("Not on this device."),
            result: .failure(ModelTestFailure.generationFailed)
        )),
        snapshotRefresher: refresher,
        now: { reprocessNow }
    )
}

private func transactionID(_ outcome: IngestionOutcome) -> UUID? {
    if case .transaction(let id) = outcome { return id }
    return nil
}

private func diagnostics(_ outcome: IngestionOutcome) -> [ParseDiagnostic] {
    if case .failed(let diagnostics) = outcome { return diagnostics }
    return []
}

// MARK: - Failed → parsed

@MainActor
@Test func failedMessageBecomesATransactionWithACheckpoint() async throws {
    let store = try makeStore()
    let rules = try store.addRule()
    let message = try store.addMessage()
    let refresher = CountingRefresher()
    let reprocessor = makeReprocessor(store, refresher: refresher)

    let outcome = await reprocessor.reprocess(message, rules: rules, mode: .rules)

    let id = try #require(transactionID(outcome))
    let transaction = try #require(try store.transactions().first)
    #expect(transaction.id == id)
    #expect(transaction.amount == Decimal(string: "12.50"))
    #expect(transaction.direction == .debit)
    #expect(transaction.merchantDisplay == "KFC")
    #expect(transaction.account.id == store.account.id)
    // The message's original instant, not the reprocess time, anchors it among the checkpoints.
    #expect(transaction.recordedAt == receivedEarlier)
    #expect(transaction.createdAt == reprocessNow)
    #expect(transaction.rawMessage?.id == message.id)
    #expect(transaction.matchedRuleID == rules[0].id)
    #expect(message.status == .parsed)
    #expect(message.engine == .rules)
    #expect(message.matchedRuleID == rules[0].id)
    #expect(message.errorDescription == nil)
    let checkpoint = try #require(try store.smsCheckpoints().first)
    #expect(checkpoint.amount == Decimal(string: "1234.50"))
    #expect(checkpoint.sourceTransactionID == id)
    #expect(checkpoint.recordedAt == receivedEarlier)
    #expect(!store.context.hasChanges)
    #expect(await refresher.refreshCount == 1)
}

@MainActor
@Test func failedMessageThatStillFailsRecordsTheNewError() async throws {
    let store = try makeStore()
    let rules = try store.addRule(pattern: #"RM(?<amount>[a-z]+) spent"#)
    let message = try store.addMessage("RMabc spent at KFC")
    let reprocessor = makeReprocessor(store)

    let outcome = await reprocessor.reprocess(message, rules: rules, mode: .rules)

    #expect(diagnostics(outcome).map(\.code) == [.invalidAmount])
    #expect(message.status == .failed)
    #expect(message.errorDescription == "The captured amount is not a number.")
    #expect(try store.transactions().isEmpty)
}

@MainActor
@Test func failedMessageThatIsNotATransactionIsIgnored() async throws {
    let store = try makeStore()
    let message = try store.addMessage("Your OTP is 123456")
    let reprocessor = makeReprocessor(store)

    let outcome = await reprocessor.reprocess(message, rules: try store.addRule(), mode: .rules)

    #expect(outcome == .notTransaction)
    #expect(message.status == .ignored)
    #expect(message.errorDescription == nil)
}

@MainActor
@Test func failedCopyOfAParsedMessageBecomesADuplicate() async throws {
    let store = try makeStore()
    let rules = try store.addRule()
    _ = try store.addMessage(status: .parsed, fingerprint: "same")
    let failedCopy = try store.addMessage(fingerprint: "same", receivedAt: receivedEarlier.addingTimeInterval(30))
    let reprocessor = makeReprocessor(store)

    let outcome = await reprocessor.reprocess(failedCopy, rules: rules, mode: .rules)

    #expect(outcome == .duplicate)
    #expect(failedCopy.status == .duplicate)
    #expect(failedCopy.errorDescription == nil)
    #expect(try store.transactions().isEmpty)
}

// MARK: - Parsed → parsed

@MainActor
@Test func parsedMessageUpdatesTheSameTransactionAndKeepsTheUsersChoices() async throws {
    let store = try makeStore()
    let rules = try store.addRule()
    let groceries = try store.category(named: "Groceries")
    let (message, transaction) = try store.addParsed(balance: 500, category: groceries, categorySource: .manual)
    let checkpointID = try #require(try store.smsCheckpoints().first?.id)
    let reprocessor = makeReprocessor(store)

    let outcome = await reprocessor.reprocess(message, rules: rules, mode: .rules)

    #expect(transactionID(outcome) == transaction.id)
    #expect(try store.transactions().count == 1)
    #expect(transaction.amount == Decimal(string: "12.50"))
    #expect(transaction.direction == .debit)
    #expect(transaction.merchantRaw == "KFC")
    #expect(transaction.merchantDisplay == "KFC")
    #expect(transaction.balanceAfter == Decimal(string: "1234.50"))
    #expect(transaction.matchedRuleID == rules[0].id)
    #expect(transaction.parseEngine == .rules)
    #expect(transaction.updatedAt == reprocessNow)
    // The person's own choices and the balance-math anchor survive.
    #expect(transaction.note == "Lunch with Sam")
    #expect(transaction.isTransfer)
    #expect(transaction.category?.id == groceries.id)
    #expect(transaction.categorySource == .manual)
    #expect(transaction.recordedAt == receivedEarlier)
    // The message's checkpoint follows the new balance instead of multiplying.
    let checkpoints = try store.smsCheckpoints()
    #expect(checkpoints.map(\.id) == [checkpointID])
    #expect(checkpoints.first?.amount == Decimal(string: "1234.50"))
    #expect(checkpoints.first?.recordedAt == receivedEarlier)
    #expect(message.status == .parsed)
}

@MainActor
@Test func parsedMessageRecategorizesACategoryThePersonDidNotChoose() async throws {
    let store = try makeStore()
    let dining = try store.category(named: "Dining")
    store.context.insert(CategorizationRule(keyword: "kfc", category: dining, priority: -100, isEnabled: true))
    let rules = try store.addRule()
    let (message, transaction) = try store.addParsed(
        balance: nil,
        category: try store.category(named: "Groceries"),
        categorySource: .rule
    )
    let reprocessor = makeReprocessor(store)

    _ = await reprocessor.reprocess(message, rules: rules, mode: .rules)

    #expect(transaction.category?.id == dining.id)
    #expect(transaction.categorySource == .rule)
}

@MainActor
@Test func parsedBalanceThatDisappearsRemovesItsCheckpoint() async throws {
    let store = try makeStore()
    let rules = try store.addRule(pattern: noBalancePattern)
    let (message, transaction) = try store.addParsed(balance: 500)
    let reprocessor = makeReprocessor(store)

    _ = await reprocessor.reprocess(message, rules: rules, mode: .rules)

    #expect(transaction.balanceAfter == nil)
    #expect(try store.smsCheckpoints().isEmpty)
    // The opening checkpoint is never touched.
    #expect(try store.context.fetchCount(FetchDescriptor<BalanceCheckpoint>()) == 1)
}

@MainActor
@Test func parsedBalanceThatAppearsAddsACheckpointAtTheOriginalInstant() async throws {
    let store = try makeStore()
    let rules = try store.addRule()
    let (message, transaction) = try store.addParsed(balance: nil)
    let reprocessor = makeReprocessor(store)

    _ = await reprocessor.reprocess(message, rules: rules, mode: .rules)

    let checkpoint = try #require(try store.smsCheckpoints().first)
    #expect(checkpoint.amount == Decimal(string: "1234.50"))
    #expect(checkpoint.sourceTransactionID == transaction.id)
    #expect(checkpoint.recordedAt == transaction.recordedAt)
    #expect(checkpoint.account.id == store.account.id)
}

@MainActor
@Test func failedReprocessLeavesTheTransactionIntact() async throws {
    let store = try makeStore()
    let rules = try store.addRule(pattern: #"spent at (?<amount>[A-Z]+)"#)
    let (message, transaction) = try store.addParsed(balance: 500)
    let reprocessor = makeReprocessor(store)

    let outcome = await reprocessor.reprocess(message, rules: rules, mode: .rules)

    #expect(diagnostics(outcome).map(\.code) == [.invalidAmount])
    #expect(transaction.amount == 99)
    #expect(transaction.merchantDisplay == "Old merchant")
    #expect(transaction.balanceAfter == 500)
    #expect(transaction.rawMessage?.id == message.id)
    #expect(try store.smsCheckpoints().first?.amount == 500)
    #expect(message.status == .parsed)
    #expect(message.errorDescription == "The captured amount is not a number.")
}

@MainActor
@Test func parsedMessageThatNoLongerReadsAsATransactionKeepsItsTransaction() async throws {
    let store = try makeStore()
    let (message, transaction) = try store.addParsed(balance: 500)
    let reprocessor = makeReprocessor(store)

    let outcome = await reprocessor.reprocess(message, rules: [], mode: .rules)

    #expect(outcome == .notTransaction)
    #expect(transaction.amount == 99)
    #expect(message.status == .parsed)
    #expect(message.transaction?.id == transaction.id)
    #expect(message.errorDescription != nil)
}

@MainActor
@Test func successfulReprocessClearsAnEarlierError() async throws {
    let store = try makeStore()
    let rules = try store.addRule()
    let (message, _) = try store.addParsed(balance: nil)
    message.errorDescription = "An earlier attempt failed."
    try store.context.save()
    let reprocessor = makeReprocessor(store)

    _ = await reprocessor.reprocess(message, rules: rules, mode: .rules)

    #expect(message.errorDescription == nil)
}

// MARK: - Accounts

@MainActor
@Test func severalAccountsWithoutAChoiceUseTheMatchedRulesAccount() async throws {
    let store = try makeStore()
    let savings = try store.addAccount("Savings", sortOrder: 1)
    let rules = try store.addRule(account: savings)
    let message = try store.addMessage()
    let reprocessor = makeReprocessor(store)

    let outcome = await reprocessor.reprocess(message, rules: rules, mode: .rules)

    #expect(transactionID(outcome) != nil)
    #expect(try store.transactions().first?.account.id == savings.id)
    #expect(message.status == .parsed)
}

@MainActor
@Test func severalAccountsAndNoMatchedRuleFailWithoutGuessingAndKeepTheStoredError() async throws {
    let store = try makeStore()
    _ = try store.addAccount("Savings", sortOrder: 1)
    let message = try store.addMessage()
    // The model reads the message, but nothing ties its answer to an account.
    let reprocessor = makeReprocessor(store, builder: ScriptedParserBuilder(result: .transaction(
        TransactionDraft(direction: .debit, amount: 12, merchant: "KFC", occurredAt: receivedEarlier)
    )))

    let outcome = await reprocessor.reprocess(message, rules: [], mode: .foundationModels)

    #expect(diagnostics(outcome).map(\.field) == ["account"])
    #expect(message.status == .failed)
    #expect(message.errorDescription == "The message could not be read.")
    #expect(try store.transactions().isEmpty)
}

@MainActor
@Test func chosenAccountReceivesTheTransaction() async throws {
    let store = try makeStore()
    let savings = try store.addAccount("Savings", sortOrder: 1)
    let rules = try store.addRule(account: savings)
    let message = try store.addMessage()
    let reprocessor = makeReprocessor(store)

    let outcome = await reprocessor.reprocess(message, accountID: savings.id, rules: rules, mode: .rules)

    #expect(transactionID(outcome) != nil)
    #expect(try store.transactions().first?.account.id == savings.id)
    #expect(try store.smsCheckpoints().first?.account.id == savings.id)
}

@MainActor
@Test func unknownChosenAccountFails() async throws {
    let store = try makeStore()
    let rules = try store.addRule()
    let message = try store.addMessage()
    let reprocessor = makeReprocessor(store)

    let outcome = await reprocessor.reprocess(message, accountID: UUID(), rules: rules, mode: .rules)

    #expect(diagnostics(outcome).map(\.field) == ["account"])
    #expect(try store.transactions().isEmpty)
}

@MainActor
@Test func parsedMessageKeepsItsTransactionsAccountAmongSeveral() async throws {
    let store = try makeStore()
    _ = try store.addAccount("Savings", sortOrder: 1)
    let rules = try store.addRule()
    let (message, transaction) = try store.addParsed(balance: nil)
    let reprocessor = makeReprocessor(store)

    let outcome = await reprocessor.reprocess(message, rules: rules, mode: .rules)

    #expect(transactionID(outcome) == transaction.id)
    #expect(transaction.account.id == store.account.id)
}

@MainActor
@Test func chosenAccountMovesAParsedTransactionAndItsCheckpoint() async throws {
    let store = try makeStore()
    let savings = try store.addAccount("Savings", sortOrder: 1)
    let rules = try store.addRule(account: savings)
    let (message, transaction) = try store.addParsed(balance: 500)
    let reprocessor = makeReprocessor(store)

    _ = await reprocessor.reprocess(message, accountID: savings.id, rules: rules, mode: .rules)

    #expect(transaction.account.id == savings.id)
    #expect(try store.smsCheckpoints().map(\.account.id) == [savings.id])
}

// MARK: - Failure paths

@MainActor
@Test func saveFailureRollsBackAndKeepsTheMessageAsItWas() async throws {
    let store = try makeStore()
    let rules = try store.addRule()
    let message = try store.addMessage()
    let reprocessor = makeReprocessor(store)
    reprocessor.saveHandler = { _ in throw CocoaError(.fileWriteUnknown) }

    let outcome = await reprocessor.reprocess(message, rules: rules, mode: .rules)

    #expect(diagnostics(outcome).map(\.field) == ["storage"])
    #expect(message.status == .failed)
    #expect(try store.transactions().isEmpty)
    #expect(try store.smsCheckpoints().isEmpty)
    #expect(try store.messages().count == 1)
}

@MainActor
@Test func cancelledReprocessChangesNothing() async throws {
    let store = try makeStore()
    let rules = try store.addRule()
    let (message, transaction) = try store.addParsed(balance: 500)
    let reprocessor = makeReprocessor(store, builder: CancellingParserBuilder())

    let outcome = await reprocessor.reprocess(message, rules: rules, mode: .rules)

    #expect(diagnostics(outcome).map(\.code) == [.cancelled])
    #expect(transaction.amount == 99)
    #expect(message.status == .parsed)
    #expect(message.errorDescription == nil)
}

// MARK: - Batch reprocessing

@MainActor
@Test func reprocessFailuresRetriesOnlyFailedMessagesOldestFirst() async throws {
    let store = try makeStore()
    let rules = try store.addRule()
    let first = try store.addMessage(fingerprint: "copy", receivedAt: receivedEarlier)
    let second = try store.addMessage(fingerprint: "copy", receivedAt: receivedEarlier.addingTimeInterval(20))
    let ignored = try store.addMessage("Your OTP is 1234", status: .ignored, fingerprint: "otp")
    let reprocessor = makeReprocessor(store)

    let outcomes = await reprocessor.reprocessFailures(rules: rules, mode: .rules)

    #expect(outcomes.count == 2)
    #expect(first.status == .parsed)
    #expect(second.status == .duplicate)
    #expect(ignored.status == .ignored)
    #expect(try store.transactions().count == 1)
}

@MainActor
@Test func reprocessFailuresWithSeveralAccountsUsesEachRulesAccountAndKeepsUnresolvedErrors() async throws {
    let store = try makeStore()
    let savings = try store.addAccount("Savings", sortOrder: 1)
    let rules = try store.addRule(account: savings)
    let readable = try store.addMessage(fingerprint: "readable")
    let unreadable = try store.addMessage("Your OTP is 1234 ref RM", fingerprint: "unreadable")
    unreadable.errorDescription = "The captured amount is not a number."
    try store.context.save()
    let reprocessor = makeReprocessor(store)

    let outcomes = await reprocessor.reprocessFailures(rules: rules, mode: .rules)

    #expect(outcomes.count == 2)
    #expect(readable.status == .parsed)
    #expect(readable.transaction?.account.id == savings.id)
    // A message no rule reads is judged on its own parse, not on the account question.
    #expect(unreadable.status == .ignored)
}

// MARK: - Balance

/// The balance the app shows for the store's account.
@MainActor
private func balance(_ store: Store) -> Decimal {
    BalanceCalculator.combined(accounts: [store.account])
}

/// Records a later debit whose SMS reported the balance, then a later manual debit, both after the
/// archived message arrived.
@MainActor
private func addLaterActivity(_ store: Store) throws {
    let smsAt = receivedEarlier.addingTimeInterval(1_800)
    let later = ZentriCore.Transaction(
        account: store.account, amount: 50, direction: .debit, occurredAt: smsAt, recordedAt: smsAt,
        merchantRaw: "Later", merchantDisplay: "Later", balanceAfter: 900, parseEngine: .rules,
        createdAt: smsAt, updatedAt: smsAt
    )
    store.context.insert(later)
    store.context.insert(BalanceCheckpoint(
        account: store.account, amount: 900, recordedAt: smsAt, source: .sms,
        sourceTransactionID: later.id, createdAt: smsAt
    ))
    let manualAt = receivedEarlier.addingTimeInterval(3_000)
    store.context.insert(ZentriCore.Transaction(
        account: store.account, amount: 20, direction: .debit, occurredAt: manualAt, recordedAt: manualAt,
        merchantRaw: "Cash", merchantDisplay: "Cash", parseEngine: .manual,
        createdAt: manualAt, updatedAt: manualAt
    ))
    try store.context.save()
}

@MainActor
@Test func reprocessingAnOldMessageWithABalanceLeavesTheLaterBalanceInCharge() async throws {
    let store = try makeStore()
    let rules = try store.addRule()
    let message = try store.addMessage()
    try addLaterActivity(store)
    #expect(balance(store) == 880)

    let outcome = await reprocessor(store).reprocess(message, rules: rules, mode: .rules)

    #expect(transactionID(outcome) != nil)
    // The bank's later balance of 900 already includes the old spend; only the 20 after it applies.
    #expect(balance(store) == 880)
}

@MainActor
@Test func reprocessingAnOldMessageWithoutABalanceIsNotCountedTwice() async throws {
    let store = try makeStore()
    let rules = try store.addRule(pattern: noBalancePattern)
    let message = try store.addMessage()
    try addLaterActivity(store)

    let outcome = await reprocessor(store).reprocess(message, rules: rules, mode: .rules)

    #expect(transactionID(outcome) != nil)
    #expect(try store.smsCheckpoints().count == 1)
    #expect(balance(store) == 880)
}

@MainActor
@Test func reprocessingAParsedMessageWhoseTransactionWasDeletedRestoresItAtTheOriginalInstant() async throws {
    let store = try makeStore()
    let rules = try store.addRule()
    let message = try store.addMessage(status: .parsed)
    try addLaterActivity(store)

    _ = await reprocessor(store).reprocess(message, rules: rules, mode: .rules)

    #expect(message.transaction?.recordedAt == receivedEarlier)
    #expect(balance(store) == 880)
}

@MainActor
private func reprocessor(_ store: Store) -> RawMessageReprocessor {
    makeReprocessor(store)
}

// MARK: - Deleting

@MainActor
@Test func clearArchiveRemovesMessagesButKeepsTransactions() async throws {
    let store = try makeStore()
    let (_, transaction) = try store.addParsed(balance: 500)
    _ = try store.addMessage(fingerprint: "another")
    let reprocessor = makeReprocessor(store)

    try reprocessor.clearArchive()

    #expect(try store.messages().isEmpty)
    #expect(try store.transactions().map(\.id) == [transaction.id])
    #expect(transaction.rawMessage == nil)
    #expect(try store.smsCheckpoints().count == 1)
}

@MainActor
@Test func deletingOneMessageDetachesItsTransaction() async throws {
    let store = try makeStore()
    let (message, transaction) = try store.addParsed(balance: nil)
    let other = try store.addMessage(fingerprint: "another")
    let reprocessor = makeReprocessor(store)

    try reprocessor.delete(message)

    #expect(try store.messages().map(\.id) == [other.id])
    #expect(try store.transactions().map(\.id) == [transaction.id])
    #expect(transaction.rawMessage == nil)
}

@MainActor
@Test func failedDeleteRollsBack() async throws {
    let store = try makeStore()
    let (message, transaction) = try store.addParsed(balance: nil)
    let reprocessor = makeReprocessor(store)
    reprocessor.saveHandler = { _ in throw CocoaError(.fileWriteUnknown) }

    #expect(throws: CocoaError.self) { try reprocessor.clearArchive() }
    #expect(try store.messages().map(\.id) == [message.id])
    #expect(transaction.rawMessage?.id == message.id)
}
