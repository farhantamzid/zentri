import Foundation
import SwiftData

/// A message offered to the ingestion pipeline.
///
/// The Shortcut supplies the text it received and, when it knows them, the sender, the message
/// date, and the account the message belongs to.
public struct IngestionRequest: Sendable, Equatable {
    /// The message exactly as it arrived; it is what the archive keeps.
    public let text: String
    /// The sender the Shortcut supplied, when it did.
    public let sender: String?
    /// The message date, or the time the message reached the app.
    public let receivedAt: Date
    /// The account the Shortcut chose, when it did. Without it the pipeline needs exactly one
    /// active account.
    public let accountID: UUID?

    public init(text: String, sender: String? = nil, receivedAt: Date, accountID: UUID? = nil) {
        self.text = text
        self.sender = sender
        self.receivedAt = receivedAt
        self.accountID = accountID
    }
}

/// What ingesting one message produced.
///
/// The outcome is what the Shortcut's dialog and the ingestion health card report. A ``failed``
/// outcome carries the diagnostics that explain it, and the message itself is always kept in the
/// archive: cancelled and interrupted work stays `processing` so it can be retried.
public enum IngestionOutcome: Sendable, Equatable {
    /// The message became this transaction, identified by its id.
    case transaction(UUID)
    /// The message repeats one that is already stored.
    case duplicate
    /// The message is not a transaction, such as a one-time password or a promotion.
    case notTransaction
    /// The message could not become a transaction; the raw message is archived for a retry.
    case failed([ParseDiagnostic])
}

/// Runs one message through normalization, dedupe, parsing, categorization, and persistence.
///
/// The service is the only writer of transactions that come from messages. It owns one
/// `ModelContext`, so it must run where that context lives; everything it needs from the rest of
/// the app — settings, the parser, and the widget snapshot — is injected, which is what makes the
/// pipeline testable without a real Shortcut, a real model, or a clock.
///
/// Every ingestion ends with exactly one ``WidgetSnapshotRefresher/refresh()`` call, whatever the
/// outcome, so the widgets and the health card never describe stale state.
@MainActor
public final class IngestionService {
    private let context: ModelContext
    private let settings: @MainActor @Sendable () -> AppSettings
    private let parserBuilder: any ParserBuilding
    private let snapshotRefresher: any WidgetSnapshotRefresher
    private let now: @Sendable () -> Date
    /// Whether the store and its sidecar files have been protected since the first save.
    private var hasProtectedStoreFiles = false
    /// The save every write goes through, replaceable so a test can make persistence fail.
    ///
    /// Production leaves this at `ModelContext.save()`. The seam exists because the failed-save
    /// fallback can only be reached by making the save throw at the instant the pipeline holds an
    /// unsaved message, which no real store can be made to do on demand. It is internal, so only
    /// the test target can replace it; the public initializer stays the only way to build a service.
    internal var saveHandler: @MainActor (ModelContext) throws -> Void = { try $0.save() }
    /// The archive rows a capture or retry in this process is parsing right now.
    ///
    /// Process-wide because a capture and the foreground retry each build their own service over the
    /// same context: a row stored `processing` by a capture that is still parsing must not be picked
    /// up and parsed a second time by a retry.
    private static var inFlightMessageIDs: Set<UUID> = []

    /// Creates the service.
    ///
    /// - Parameters:
    ///   - context: The context every write goes through.
    ///   - settings: The current settings, read once per message so a parser-mode change applies to
    ///     the next ingestion without rebuilding the service.
    ///   - parserBuilder: The builder for the parser the settings mode asks for.
    ///   - snapshotRefresher: The refresher called once after every outcome.
    ///   - now: The clock. Pass a fixed closure in tests; production passes the system clock at the
    ///     composition root so no time is read from a global here.
    public init(
        context: ModelContext,
        settings: @escaping @MainActor @Sendable () -> AppSettings,
        parserBuilder: any ParserBuilding,
        snapshotRefresher: any WidgetSnapshotRefresher,
        now: @escaping @Sendable () -> Date
    ) {
        self.context = context
        self.settings = settings
        self.parserBuilder = parserBuilder
        self.snapshotRefresher = snapshotRefresher
        self.now = now
    }

    // MARK: - Ingesting

    /// Ingests one message.
    ///
    /// The message is archived whatever happens. A transaction and, when the message states one, a
    /// balance checkpoint are written with it in one save, so a failure can never leave a
    /// transaction without its message.
    ///
    /// - Parameter request: The message and what the caller knows about it.
    /// - Returns: The outcome the caller reports to the user.
    public func ingest(_ request: IngestionRequest) async -> IngestionOutcome {
        let outcome = await ingestMessage(request)
        await snapshotRefresher.refresh()
        return outcome
    }

    /// Retries every message that an interruption or a cancellation left `processing`.
    ///
    /// Messages are retried oldest first, each against its existing archive row: no new raw message
    /// is created, and a row never counts as its own duplicate. A message whose parse still fails is
    /// marked `failed`; a cancelled one stays `processing` so the next launch tries again.
    ///
    /// - Returns: One outcome per retried message, in `receivedAt` order.
    public func retryPending() async -> [IngestionOutcome] {
        let pending = ((try? context.fetch(FetchDescriptor<RawMessage>())) ?? [])
            .filter { $0.status == .processing && !Self.inFlightMessageIDs.contains($0.id) }
            .sorted { lhs, rhs in
                if lhs.receivedAt != rhs.receivedAt {
                    return lhs.receivedAt < rhs.receivedAt
                }
                return lhs.id.uuidString < rhs.id.uuidString
            }

        var outcomes: [IngestionOutcome] = []
        for message in pending {
            let outcome = await retry(message)
            await snapshotRefresher.refresh()
            outcomes.append(outcome)
        }
        return outcomes
    }

    // MARK: - Pipeline

    /// The ingest pipeline for one message, without the snapshot refresh that follows it.
    ///
    /// The account is settled before parsing when the request names one or only one is active; then
    /// only that account's rules run. With several active accounts and no choice every rule runs and
    /// the matched rule's account receives the transaction, as a launch retry does.
    ///
    /// Duplicates are checked before parsing with whatever account is known — none, for an unresolved
    /// capture, whose fingerprint and archive row then carry no account, so re-running the same
    /// automation still matches exactly. Once a rule resolves the account the check runs again with
    /// that account, because without a sender the recent-duplicate window keys on the account.
    private func ingestMessage(_ request: IngestionRequest) async -> IngestionOutcome {
        let ingestedAt = now()

        let account: Account?
        switch resolvedAccount(for: request) {
        case .resolved(let resolved):
            account = resolved
        case .byMatchedRule:
            account = nil
        case .failed(let diagnostic):
            // The message is still archived, with the chosen account as the only identity available.
            let message = makeMessage(
                for: request,
                ingestedAt: ingestedAt,
                status: .failed,
                errorDescription: diagnostic.message,
                fingerprint: Dedupe.fingerprint(
                    text: request.text,
                    sender: request.sender,
                    accountID: request.accountID,
                    receivedAt: request.receivedAt
                )
            )
            return persist(message) ? .failed([diagnostic]) : .failed([diagnostic, IngestionDiagnostics.storage])
        }

        let fingerprint = Dedupe.fingerprint(
            text: request.text,
            sender: request.sender,
            accountID: account?.id,
            receivedAt: request.receivedAt
        )
        if isDuplicate(fingerprint: fingerprint, request: request, accountID: account?.id, excluding: nil) {
            return archiveDuplicate(request, ingestedAt: ingestedAt, fingerprint: fingerprint)
        }

        // The message is archived before parsing, so a process killed mid-parse (or a parse that
        // never returns) leaves a `processing` row the next launch retries, and a second capture of
        // the same text arriving while this one is parsing sees it and stops as a duplicate.
        let message = makeMessage(
            for: request,
            ingestedAt: ingestedAt,
            status: .processing,
            fingerprint: fingerprint
        )
        guard persist(message) else {
            return recordStorageFailure(for: request, ingestedAt: ingestedAt, fingerprint: fingerprint)
        }
        Self.inFlightMessageIDs.insert(message.id)
        defer { Self.inFlightMessageIDs.remove(message.id) }

        let result = await parse(request, accountID: account?.id)

        switch ParseDisposition(classifying: result) {
        case .transaction(let draft):
            let target: Account
            if let account {
                target = account
            } else {
                guard let ruleAccount = store.ruleAccount(for: draft) else {
                    // No stored rule produced the answer, so nothing says which account it belongs to.
                    let diagnostic = IngestionDiagnostics.chooseAccount
                    return finish(message, as: .failed, errorDescription: diagnostic.message)
                        ? .failed([diagnostic])
                        : .failed([diagnostic, IngestionDiagnostics.storage])
                }
                let resolvedFingerprint = Dedupe.fingerprint(
                    text: request.text,
                    sender: request.sender,
                    accountID: ruleAccount.id,
                    receivedAt: request.receivedAt
                )
                if isDuplicate(
                    fingerprint: resolvedFingerprint,
                    request: request,
                    accountID: ruleAccount.id,
                    excluding: message.id
                ) {
                    return finish(message, as: .duplicate) ? .duplicate : .failed([IngestionDiagnostics.storage])
                }
                target = ruleAccount
            }
            return persist(draft: draft, account: target, message: message, recordedAt: ingestedAt)
        case .notTransaction:
            return finish(message, as: .ignored) ? .notTransaction : .failed([IngestionDiagnostics.storage])
        case .failed(let diagnostics):
            return finish(
                message,
                as: .failed,
                errorDescription: IngestionDiagnostics.errorDescription(of: diagnostics)
            ) ? .failed(diagnostics) : .failed(diagnostics + [IngestionDiagnostics.storage])
        case .cancelled(let diagnostics):
            // Cancelled work is retryable, never archived as a verdict on the message: the row is
            // already stored as `processing`, so it is left as it is.
            return .failed(diagnostics.isEmpty ? [IngestionDiagnostics.cancelled] : diagnostics)
        }
    }

    /// Archives a message without parsing it, as `processing`, so a later retry reads it.
    ///
    /// For a capture that arrives while the settings cannot be read: the accounts and rules are
    /// still there, but the parser mode is unknown, so the message is kept for the retry that runs
    /// once the settings are readable again rather than dropped. A repeat of a stored message is
    /// archived as a duplicate, as ingestion would.
    ///
    /// - Returns: ``IngestionOutcome/duplicate`` for a repeat; otherwise a failure carrying
    ///   `diagnostic`, plus the storage diagnostic when the row could not be saved.
    public func archiveForRetry(_ request: IngestionRequest, reporting diagnostic: ParseDiagnostic) async -> IngestionOutcome {
        let outcome = archiveUnparsed(request, reporting: diagnostic)
        await snapshotRefresher.refresh()
        return outcome
    }

    private func archiveUnparsed(_ request: IngestionRequest, reporting diagnostic: ParseDiagnostic) -> IngestionOutcome {
        let ingestedAt = now()
        let accountID: UUID?
        switch resolvedAccount(for: request) {
        case .resolved(let account):
            accountID = account.id
        case .byMatchedRule, .failed:
            accountID = nil
        }
        let fingerprint = Dedupe.fingerprint(
            text: request.text,
            sender: request.sender,
            accountID: accountID,
            receivedAt: request.receivedAt
        )
        if isDuplicate(fingerprint: fingerprint, request: request, accountID: accountID, excluding: nil) {
            return archiveDuplicate(request, ingestedAt: ingestedAt, fingerprint: fingerprint)
        }
        let message = makeMessage(for: request, ingestedAt: ingestedAt, status: .processing, fingerprint: fingerprint)
        return persist(message) ? .failed([diagnostic]) : .failed([diagnostic, IngestionDiagnostics.storage])
    }

    /// Archives a repeat of a stored message, with no transaction and no balance change.
    private func archiveDuplicate(
        _ request: IngestionRequest,
        ingestedAt: Date,
        fingerprint: String
    ) -> IngestionOutcome {
        let message = makeMessage(
            for: request,
            ingestedAt: ingestedAt,
            status: .duplicate,
            fingerprint: fingerprint
        )
        return persist(message) ? .duplicate : .failed([IngestionDiagnostics.storage])
    }

    /// The retry pipeline for one existing archive row.
    ///
    /// The transaction is recorded at the message's `ingestedAt`, as the reprocessor does: recording
    /// it at the retry instant would place an older bank balance after newer ones.
    private func retry(_ message: RawMessage) async -> IngestionOutcome {
        let request = IngestionRequest(
            text: message.text,
            sender: message.sender,
            receivedAt: message.receivedAt,
            accountID: nil
        )
        // A cancelled retry changes nothing, so the row is still `processing` for the next launch.
        guard !Task.isCancelled else { return .failed([IngestionDiagnostics.cancelled]) }

        Self.inFlightMessageIDs.insert(message.id)
        defer { Self.inFlightMessageIDs.remove(message.id) }

        let fingerprint = message.fingerprint
        let accounts = activeAccounts()
        // The capture's account, when it had one, is part of the row's fingerprint; recovering it
        // keeps the retry on the account the Shortcut chose rather than guessing among several.
        let capturedAccount = accounts.first { account in
            Dedupe.fingerprint(
                text: message.text,
                sender: message.sender,
                accountID: account.id,
                receivedAt: message.receivedAt
            ) == fingerprint
        }
        let hintedAccount = capturedAccount ?? (accounts.count == 1 ? accounts[0] : nil)

        if isDuplicate(
            fingerprint: fingerprint,
            request: request,
            accountID: hintedAccount?.id,
            excluding: message.id
        ) {
            return finish(message, as: .duplicate) ? .duplicate : .failed([IngestionDiagnostics.storage])
        }

        // Without a recovered account every rule runs; the matched rule or the single active account
        // decides where the transaction lands.
        let result = await parse(request, accountID: capturedAccount?.id)

        switch ParseDisposition(classifying: result) {
        case .transaction(let draft):
            guard let account = capturedAccount ?? retryAccount(for: draft, among: accounts) else {
                // Nothing identifies an account, so the row stays retryable rather than guessed at.
                return .failed([IngestionDiagnostics.retryAccount])
            }
            return persist(draft: draft, account: account, message: message, recordedAt: message.ingestedAt)
        case .notTransaction:
            return finish(message, as: .ignored) ? .notTransaction : .failed([IngestionDiagnostics.storage])
        case .failed(let diagnostics):
            return finish(
                message,
                as: .failed,
                errorDescription: IngestionDiagnostics.errorDescription(of: diagnostics)
            ) ? .failed(diagnostics) : .failed(diagnostics + [IngestionDiagnostics.storage])
        case .cancelled(let diagnostics):
            // Left `processing`: the message is retried on the next launch.
            return .failed(diagnostics.isEmpty ? [IngestionDiagnostics.cancelled] : diagnostics)
        }
    }

    /// Records a verdict on a stored row and saves it. A failed save rolls back, leaving the row as
    /// it was last saved — `processing` — so the next retry reads it again.
    private func finish(_ message: RawMessage, as status: ParseStatus, errorDescription: String? = nil) -> Bool {
        message.status = status
        message.engine = nil
        message.matchedRuleID = nil
        message.errorDescription = errorDescription
        return save()
    }

    /// Parses one message with the parser the current settings ask for.
    private func parse(_ request: IngestionRequest, accountID: UUID?) async -> ParseResult {
        let appSettings = settings()
        let parser = parserBuilder.makeParser(for: appSettings.parserMode, rules: parsingRuleSpecs())
        let input = ParseInput(
            text: MessageText.normalizedForParsing(request.text),
            accountID: accountID,
            sender: request.sender,
            receivedAt: request.receivedAt
        )
        return await parser.parse(input)
    }

    // MARK: - Persistence

    /// Writes the parsed transaction and an optional checkpoint, linked to the stored message, in
    /// one save.
    ///
    /// A save failure rolls the transaction and checkpoint back and marks the message `failed` on
    /// its own, so no transaction is ever left half-written and the text is never lost.
    ///
    /// The draft is not validated again: every engine runs ``TransactionValidator`` before it
    /// returns a ``ParseResult/transaction(_:)``, and a second pass here would only be a weaker copy
    /// of those checks.
    private func persist(
        draft: TransactionDraft,
        account: Account,
        message: RawMessage,
        recordedAt: Date
    ) -> IngestionOutcome {
        let transaction = store.insertTransaction(
            from: draft,
            account: account,
            message: message,
            recordedAt: recordedAt
        )
        let transactionID = transaction.id

        guard save() else {
            // The rollback restored the message to its saved `processing` state; if even this save
            // fails it stays `processing` and is retried.
            _ = finish(message, as: .failed, errorDescription: IngestionDiagnostics.storage.message)
            return .failed([IngestionDiagnostics.storage])
        }
        return .transaction(transactionID)
    }

    /// Stores one archive row without a transaction.
    @discardableResult
    private func persist(_ message: RawMessage) -> Bool {
        context.insert(message)
        return save()
    }

    /// Stores the message on its own after a failed save, so the text is never lost.
    ///
    /// The failed attempt has already been rolled back, which discarded the row it inserted, so the
    /// row built here is the only pending insert: the archive ends up with one `failed` row.
    private func recordStorageFailure(
        for request: IngestionRequest,
        ingestedAt: Date,
        fingerprint: String
    ) -> IngestionOutcome {
        let message = RawMessage(
            text: request.text,
            sender: request.sender,
            receivedAt: request.receivedAt,
            ingestedAt: ingestedAt,
            status: .failed,
            errorDescription: IngestionDiagnostics.storage.message,
            fingerprint: fingerprint
        )
        persist(message)
        return .failed([IngestionDiagnostics.storage])
    }

    /// Saves the context, rolling back so a throw cannot leave partial rows behind.
    ///
    /// The first successful save is also where the SQLite sidecar files appear, so protection is
    /// reapplied there; a store created before any save has nothing to protect yet.
    private func save() -> Bool {
        do {
            try saveHandler(context)
            protectStoreFilesAfterFirstSave()
            return true
        } catch {
            context.rollback()
            return false
        }
    }

    /// Applies the background-safe file protection once the store files exist.
    private func protectStoreFilesAfterFirstSave() {
        guard !hasProtectedStoreFiles else { return }
        hasProtectedStoreFiles = true
        ZentriContainer.protectStoreFiles(for: context.container)
    }

    // MARK: - Models

    /// A raw message for `request`, not yet inserted.
    private func makeMessage(
        for request: IngestionRequest,
        ingestedAt: Date,
        status: ParseStatus,
        engine: ParseEngine? = nil,
        matchedRuleID: UUID? = nil,
        errorDescription: String? = nil,
        fingerprint: String
    ) -> RawMessage {
        RawMessage(
            text: request.text,
            sender: request.sender,
            receivedAt: request.receivedAt,
            ingestedAt: ingestedAt,
            status: status,
            engine: engine,
            matchedRuleID: matchedRuleID,
            errorDescription: errorDescription,
            fingerprint: fingerprint
        )
    }

    /// The account the message belongs to.
    ///
    /// An account the Shortcut chose wins, and a single active account is used. With several and no
    /// choice the matched rule decides after parsing; nothing is guessed, because a transaction on the
    /// wrong account corrupts both balances.
    private func resolvedAccount(for request: IngestionRequest) -> AccountResolution {
        let accounts = activeAccounts()
        if let accountID = request.accountID {
            guard let account = accounts.first(where: { $0.id == accountID }) else {
                return .failed(accounts.isEmpty ? IngestionDiagnostics.addAccount : IngestionDiagnostics.chooseAccount)
            }
            return .resolved(account)
        }
        switch accounts.count {
        case 1:
            return .resolved(accounts[0])
        case 0:
            return .failed(IngestionDiagnostics.addAccount)
        default:
            return .byMatchedRule
        }
    }

    /// The account a retried transaction belongs to: the matched rule's, or the single active one.
    private func retryAccount(for draft: TransactionDraft, among accounts: [Account]) -> Account? {
        store.ruleAccount(for: draft) ?? (accounts.count == 1 ? accounts[0] : nil)
    }

    /// The non-archived accounts, in the order an account picker shows them.
    private func activeAccounts() -> [Account] {
        store.activeAccounts()
    }

    /// The stored rules as parser specs, in the order the engine must evaluate them.
    private func parsingRuleSpecs() -> [ParsingRuleSpec] {
        (try? StoredParsingRules.specs(in: context)) ?? []
    }

    // MARK: - Account resolution

    /// What resolving an account produced.
    private enum AccountResolution {
        /// The account the transaction belongs to.
        case resolved(Account)
        /// Several accounts and no choice: the matched rule's account, known only after parsing.
        case byMatchedRule
        /// Why no account could be chosen.
        case failed(ParseDiagnostic)
    }

    // MARK: - Shared helpers

    /// The reads and writes ingestion shares with reprocessing.
    private var store: IngestionStore {
        IngestionStore(context: context)
    }

    /// Whether the message is already in the archive; see ``IngestionStore/isDuplicate(fingerprint:text:sender:receivedAt:accountID:excluding:)``.
    private func isDuplicate(
        fingerprint: String,
        request: IngestionRequest,
        accountID: UUID?,
        excluding excludedID: UUID?
    ) -> Bool {
        store.isDuplicate(
            fingerprint: fingerprint,
            text: request.text,
            sender: request.sender,
            receivedAt: request.receivedAt,
            accountID: accountID,
            excluding: excludedID
        )
    }
}
