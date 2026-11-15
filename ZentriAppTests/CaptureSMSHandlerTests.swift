import Foundation
import SwiftData
import Testing
import ZentriCore
@testable import ZentriApp

// MARK: - Test doubles

/// Counts snapshot refreshes so a test can prove a capture refreshed the widgets exactly once.
private actor CaptureSpyRefresher: WidgetSnapshotRefresher {
    private(set) var refreshCount = 0

    func refresh() async {
        refreshCount += 1
    }
}

/// A parser that always answers with the same result.
private struct CaptureStubParser: TransactionParsing {
    let result: ParseResult

    func parse(_ input: ParseInput) async -> ParseResult {
        result
    }
}

/// The parser modes a builder was asked for, guarded by a lock because the builder is `Sendable`.
private final class CaptureModeRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [ParserMode] = []

    var modes: [ParserMode] {
        lock.withLock { recorded }
    }

    func record(_ mode: ParserMode) {
        lock.withLock { recorded.append(mode) }
    }
}

/// A builder that hands back one scripted parser and records the mode it was asked for.
private struct CaptureStubParserBuilder: ParserBuilding {
    let result: ParseResult
    var recorder: CaptureModeRecorder?

    func makeParser(for mode: ParserMode, rules: [ParsingRuleSpec]) -> any TransactionParsing {
        recorder?.record(mode)
        return CaptureStubParser(result: result)
    }
}

// MARK: - Fixtures

/// A 12.50 debit at KFC, as a rule would read it.
private let kfcDraft = TransactionDraft(direction: .debit, amount: Decimal(string: "12.50") ?? 0, merchant: "KFC")

/// The locale the dialogs are checked in, so `$12.50` does not depend on the simulator's region.
private let dialogLocale = Locale(identifier: "en_US")

private func captureRequest(
    text: String = "MYBANK: USD12.50 spent at KFC.",
    accountID: UUID? = nil
) -> IngestionRequest {
    IngestionRequest(text: text, sender: "MYBANK", receivedAt: .now, accountID: accountID)
}

/// Settings saved through onboarding: USD, Western grouping.
@MainActor
private func completedSettings(mode: ParserMode = .rules) throws -> SettingsStore {
    let store = SettingsStore(repository: InMemorySettingsRepository())
    try store.save(AppSettings(parserMode: mode))
    return store
}

@MainActor
private func makeHandler(
    _ store: ParsingTestStore,
    settings: SettingsStore,
    result: ParseResult = .transaction(kfcDraft),
    recorder: CaptureModeRecorder? = nil,
    refresher: any WidgetSnapshotRefresher = CaptureSpyRefresher()
) -> CaptureSMSHandler {
    CaptureSMSHandler(
        container: store.container,
        settingsStore: settings,
        parserBuilder: CaptureStubParserBuilder(result: result, recorder: recorder),
        snapshotRefresher: refresher
    )
}

@MainActor
private func dialog(_ handler: CaptureSMSHandler, _ outcome: IngestionOutcome) -> String {
    String(localized: handler.dialog(for: outcome, locale: dialogLocale))
}

// MARK: - Outcomes

@MainActor
@Suite
struct CaptureSMSHandlerTests {
    @Test func validMessageBecomesAStoredTransaction() async throws {
        let store = try ParsingTestStore()
        let handler = makeHandler(store, settings: try completedSettings())

        let outcome = await handler.handle(captureRequest())

        guard case .transaction(let id) = outcome else {
            Issue.record("Expected a transaction, got \(outcome)")
            return
        }
        let transactions = try store.context.fetch(FetchDescriptor<ZentriCore.Transaction>())
        #expect(transactions.map(\.id) == [id])
        #expect(transactions.first?.merchantDisplay == "KFC")
        #expect(transactions.first?.account.id == store.account.id)
        #expect(transactions.first?.rawMessage?.status == .parsed)
        #expect(dialog(handler, outcome) == "Recorded $12.50 at KFC.")
    }

    @Test func creditDialogSaysWhereTheMoneyCameFrom() async throws {
        let store = try ParsingTestStore()
        let salary = TransactionDraft(direction: .credit, amount: 2_500, merchant: "Acme Payroll")
        let handler = makeHandler(store, settings: try completedSettings(), result: .transaction(salary))

        let outcome = await handler.handle(captureRequest(text: "MYBANK: USD2500 received from Acme Payroll."))

        #expect(dialog(handler, outcome) == "Recorded $2,500.00 from Acme Payroll.")
    }

    @Test func repeatedMessageIsADuplicate() async throws {
        let store = try ParsingTestStore()
        let handler = makeHandler(store, settings: try completedSettings())
        let request = captureRequest()

        _ = await handler.handle(request)
        let outcome = await handler.handle(request)

        #expect(outcome == .duplicate)
        #expect(try store.context.fetchCount(FetchDescriptor<ZentriCore.Transaction>()) == 1)
        #expect(dialog(handler, outcome) == "This message is already in Zentri, so nothing was added.")
    }

    @Test func missingSettingsAsksToFinishSetupWithoutTouchingTheStore() async throws {
        let store = try ParsingTestStore()
        let refresher = CaptureSpyRefresher()
        let settings = SettingsStore(repository: InMemorySettingsRepository())
        try settings.load()
        let handler = makeHandler(store, settings: settings, refresher: refresher)

        let outcome = await handler.handle(captureRequest())

        guard case .failed = outcome else {
            Issue.record("Expected a failure, got \(outcome)")
            return
        }
        #expect(dialog(handler, outcome) == "Open Zentri to finish setup.")
        #expect(try store.context.fetchCount(FetchDescriptor<RawMessage>()) == 0)
        #expect(await refresher.refreshCount == 0)
    }

    @Test func captureRefreshesTheWidgetSnapshotExactlyOnce() async throws {
        let store = try ParsingTestStore()
        let refresher = CaptureSpyRefresher()
        let handler = makeHandler(store, settings: try completedSettings(), refresher: refresher)

        _ = await handler.handle(captureRequest())

        #expect(await refresher.refreshCount == 1)
    }

    @Test func notATransactionIsArchivedAndSaysSo() async throws {
        let store = try ParsingTestStore()
        let handler = makeHandler(store, settings: try completedSettings(), result: .notTransaction)

        let outcome = await handler.handle(captureRequest(text: "Your code is 123456."))

        #expect(outcome == .notTransaction)
        #expect(try store.context.fetch(FetchDescriptor<RawMessage>()).map(\.status) == [.ignored])
        #expect(dialog(handler, outcome) == "This message isn't a transaction, so nothing was added.")
    }

    @Test func failureGivesTheReasonAndKeepsTheMessage() async throws {
        let store = try ParsingTestStore()
        let failure = ParseResult.failure([
            ParseDiagnostic(code: .invalidAmount, field: "amount", message: "The captured amount is not a number."),
        ])
        let handler = makeHandler(store, settings: try completedSettings(), result: failure)

        let outcome = await handler.handle(captureRequest())

        #expect(try store.context.fetch(FetchDescriptor<RawMessage>()).map(\.status) == [.failed])
        #expect(
            dialog(handler, outcome)
                == "Zentri couldn't read this message. The captured amount isn't a number Zentri can read. It's saved in the message inbox."
        )
    }

    /// A cancelled parse leaves the message `processing` for the next launch, so the dialog must not
    /// call it a failure or a transaction.
    @Test func cancelledCaptureSaysItWillFinishWhenZentriOpens() async throws {
        let store = try ParsingTestStore()
        let cancelled = ParseResult.failure([ParseDiagnostic(code: .cancelled, message: "Parsing was cancelled.")])
        let handler = makeHandler(store, settings: try completedSettings(), result: cancelled)

        let outcome = await handler.handle(captureRequest())

        #expect(try store.context.fetch(FetchDescriptor<RawMessage>()).map(\.status) == [.processing])
        #expect(dialog(handler, outcome) == "The message was saved and will finish when Zentri opens.")
    }

    @Test func severalAccountsWithoutAChoiceAskForOneInTheShortcut() async throws {
        let store = try ParsingTestStore()
        try store.addAccount("Savings", sortOrder: 1)
        let handler = makeHandler(store, settings: try completedSettings())

        let outcome = await handler.handle(captureRequest())

        #expect(try store.context.fetch(FetchDescriptor<RawMessage>()).map(\.status) == [.failed])
        #expect(
            dialog(handler, outcome)
                == "Zentri couldn't tell which account this message belongs to. Choose an account in the Shortcut. It's saved in the message inbox."
        )
    }

    @Test func chosenAccountReceivesTheTransaction() async throws {
        let store = try ParsingTestStore()
        let savings = try store.addAccount("Savings", sortOrder: 1)
        let handler = makeHandler(store, settings: try completedSettings())

        let outcome = await handler.handle(captureRequest(accountID: savings.id))

        guard case .transaction(let id) = outcome else {
            Issue.record("Expected a transaction, got \(outcome)")
            return
        }
        let transaction = try store.context.fetch(FetchDescriptor<ZentriCore.Transaction>()).first { $0.id == id }
        #expect(transaction?.account.id == savings.id)
    }

    @Test func emptyTextIsRejectedWithoutArchivingAnything() async throws {
        let store = try ParsingTestStore()
        let refresher = CaptureSpyRefresher()
        let handler = makeHandler(store, settings: try completedSettings(), refresher: refresher)

        let outcome = await handler.handle(captureRequest(text: "  \n "))

        guard case .failed = outcome else {
            Issue.record("Expected a failure, got \(outcome)")
            return
        }
        #expect(dialog(handler, outcome) == "The Shortcut didn't pass any message text. Set SMS Text to the message's content.")
        #expect(try store.context.fetchCount(FetchDescriptor<RawMessage>()) == 0)
        #expect(await refresher.refreshCount == 0)
    }

    /// The parser mode is read for every message, so a change made after the handler was built applies.
    @Test func parserModeFollowsTheLiveSettings() async throws {
        let store = try ParsingTestStore()
        let settings = try completedSettings(mode: .rules)
        let recorder = CaptureModeRecorder()
        let handler = makeHandler(store, settings: settings, result: .notTransaction, recorder: recorder)

        _ = await handler.handle(captureRequest(text: "First"))
        try settings.save(AppSettings(parserMode: .hybrid))
        _ = await handler.handle(captureRequest(text: "Second"))

        #expect(recorder.modes == [.rules, .hybrid])
    }
}
