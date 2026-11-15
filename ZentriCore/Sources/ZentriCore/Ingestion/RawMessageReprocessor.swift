import Foundation
import SwiftData

/// Runs archived messages through the parser again, and removes messages from the archive.
///
/// Reprocessing is how a person recovers after fixing a rule: a failed message can become a
/// transaction, and a parsed message can be read again with the corrected rule. The guarantees:
///
/// - **A transaction is replaced only after a successful parse.** Reprocessing a parsed message
///   updates the *same* transaction in place — amount, direction, date, merchant, balance, engine,
///   and matched rule — and keeps the person's note, transfer flag, and a category they chose
///   themselves. Its `recordedAt` stays put, because that instant anchors it among the balance
///   checkpoints. A parse that fails, finds no transaction, or is cancelled leaves the transaction
///   exactly as it was and only records the error on the message.
/// - **The message's SMS checkpoint follows the new balance.** A balance that changes updates the
///   checkpoint the message established; a balance that appears adds one at the transaction's
///   original instant; a balance that disappears removes the checkpoint, because the parse that
///   produced it is the one being replaced. Opening and manual checkpoints are never touched. This
///   is the one place a checkpoint is removed without deleting its account, and it only happens
///   because the person confirmed the reprocess.
/// - **The account is never guessed.** It is the one the caller chose, else the existing
///   transaction's, else the only active account. Otherwise every rule runs and the transaction
///   lands on the matched rule's account, as the launch retry does. Only a transaction no rule
///   produced fails with an account diagnostic, and the message keeps its stored error, so the
///   caller can ask the person without losing why the message failed before.
/// - **A new transaction keeps the message's original instant.** Its `recordedAt`, and its SMS
///   checkpoint's, is when the message was first ingested, not when it was reprocessed: a later
///   bank balance already includes it, and an old balance must not outrank a newer one.
/// - **Deleting messages never deletes transactions.** A deleted message's transaction is detached
///   and stays in the history.
///
/// Every reprocess ends with one ``WidgetSnapshotRefresher/refresh()``, whatever the outcome.
@MainActor
public final class RawMessageReprocessor {
    private let context: ModelContext
    private let parserBuilder: any ParserBuilding
    private let snapshotRefresher: any WidgetSnapshotRefresher
    private let now: @Sendable () -> Date

    /// The save every write goes through, replaceable so a test can make persistence fail.
    internal var saveHandler: @MainActor (ModelContext) throws -> Void = { try $0.save() }

    /// Creates the reprocessor.
    ///
    /// - Parameters:
    ///   - context: The context every read and write goes through.
    ///   - parserBuilder: The builder for the parser the caller's mode asks for.
    ///   - snapshotRefresher: The refresher called once after every reprocess.
    ///   - now: The clock that stamps a new transaction's `recordedAt` and an edit's `updatedAt`.
    public init(
        context: ModelContext,
        parserBuilder: any ParserBuilding,
        snapshotRefresher: any WidgetSnapshotRefresher,
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.context = context
        self.parserBuilder = parserBuilder
        self.snapshotRefresher = snapshotRefresher
        self.now = now
    }

    // MARK: - Reprocessing

    /// Parses `message` again with `rules` and `mode`.
    ///
    /// - Parameters:
    ///   - message: The archived message.
    ///   - accountID: The account the person chose, or `nil` to use the message's transaction's
    ///     account or the only active account.
    ///   - rules: The rules to parse with, normally ``StoredParsingRules/specs(in:)``.
    ///   - mode: The parser mode to use, normally the saved setting.
    /// - Returns: The transaction the message now describes, or why it does not describe one.
    public func reprocess(
        _ message: RawMessage,
        accountID: UUID? = nil,
        rules: [ParsingRuleSpec],
        mode: ParserMode
    ) async -> IngestionOutcome {
        let outcome = await reprocessMessage(message, accountID: accountID, rules: rules, mode: mode)
        await snapshotRefresher.refresh()
        return outcome
    }

    /// Reprocesses every failed message, oldest first, after the person changed their rules.
    ///
    /// Each message resolves its account on its own: with several accounts, a message a rule reads
    /// lands on that rule's account, and one only the model reads fails with an account diagnostic
    /// while keeping its stored error. Copies of one message are handled in order: once the first
    /// parses, the rest are duplicates.
    ///
    /// - Returns: One outcome per failed message, in `receivedAt` order.
    public func reprocessFailures(rules: [ParsingRuleSpec], mode: ParserMode) async -> [IngestionOutcome] {
        let failed = ((try? context.fetch(FetchDescriptor<RawMessage>())) ?? [])
            .filter { $0.status == .failed }
            .sorted { lhs, rhs in
                if lhs.receivedAt != rhs.receivedAt {
                    return lhs.receivedAt < rhs.receivedAt
                }
                return lhs.id.uuidString < rhs.id.uuidString
            }
        var outcomes: [IngestionOutcome] = []
        for message in failed {
            guard !Task.isCancelled else { break }
            outcomes.append(await reprocessMessage(message, accountID: nil, rules: rules, mode: mode))
        }
        await snapshotRefresher.refresh()
        return outcomes
    }

    // MARK: - Deleting

    /// Deletes one message from the archive, keeping its transaction.
    public func delete(_ message: RawMessage) throws {
        detach(message)
        context.delete(message)
        try commit()
    }

    /// Deletes every archived message, keeping every transaction.
    ///
    /// Transactions lose only their link to the message text; their amounts, checkpoints, and
    /// history are unchanged, so the balance stays the same.
    public func clearArchive() throws {
        for message in try context.fetch(FetchDescriptor<RawMessage>()) {
            detach(message)
            context.delete(message)
        }
        try commit()
    }

    // MARK: - Pipeline

    private func reprocessMessage(
        _ message: RawMessage,
        accountID: UUID?,
        rules: [ParsingRuleSpec],
        mode: ParserMode
    ) async -> IngestionOutcome {
        guard !Task.isCancelled else { return .failed([IngestionDiagnostics.cancelled]) }
        let existing = message.transaction

        let knownAccount: Account?
        switch resolvedAccount(chosen: accountID, existing: existing) {
        case .resolved(let account):
            knownAccount = account
        case .unknownChoice:
            return recordFailure([IngestionDiagnostics.retryAccount], on: message, keeping: existing)
        case .undecided:
            knownAccount = nil
        }

        // A message that already has its transaction is the original, so only an unlinked message
        // can turn out to repeat another one.
        if existing == nil, store.isDuplicate(
            fingerprint: message.fingerprint,
            text: message.text,
            sender: message.sender,
            receivedAt: message.receivedAt,
            accountID: knownAccount?.id,
            excluding: message.id
        ) {
            message.status = .duplicate
            message.engine = nil
            message.matchedRuleID = nil
            message.errorDescription = nil
            return committed(.duplicate)
        }

        // Without a known account every rule runs, and the matched rule decides the account.
        let parser = parserBuilder.makeParser(for: mode, rules: rules)
        let result = await parser.parse(ParseInput(
            text: MessageText.normalizedForParsing(message.text),
            accountID: knownAccount?.id,
            sender: message.sender,
            receivedAt: message.receivedAt
        ))

        switch ParseDisposition(classifying: result) {
        case .transaction(let draft):
            guard let account = knownAccount ?? store.ruleAccount(for: draft) else {
                // Nothing ties the answer to an account. The message keeps its stored error, which
                // still explains it, and the caller asks the person which account it belongs to.
                return .failed([IngestionDiagnostics.retryAccount])
            }
            if let existing {
                update(existing, from: draft, account: account, message: message)
                return committed(.transaction(existing.id))
            }
            let transaction = store.insertTransaction(
                from: draft,
                account: account,
                message: message,
                recordedAt: message.ingestedAt,
                createdAt: now()
            )
            return committed(.transaction(transaction.id))
        case .notTransaction:
            if existing != nil {
                message.errorDescription = Self.keptTransactionDescription
                return committed(.notTransaction)
            }
            message.status = .ignored
            message.engine = nil
            message.matchedRuleID = nil
            message.errorDescription = nil
            return committed(.notTransaction)
        case .failed(let diagnostics):
            return recordFailure(diagnostics, on: message, keeping: existing)
        case .cancelled(let diagnostics):
            // Nothing has changed; the person can try again.
            return .failed(diagnostics.isEmpty ? [IngestionDiagnostics.cancelled] : diagnostics)
        }
    }

    /// Replaces the parsed fields of an existing transaction, keeping the person's own choices.
    private func update(
        _ transaction: Transaction,
        from draft: TransactionDraft,
        account: Account,
        message: RawMessage
    ) {
        let merchantRaw = MessageText.collapsedWhitespace(draft.merchant)
        let merchantDisplay = MessageText.displayMerchant(from: merchantRaw)
        let previousAccount = transaction.account

        transaction.account = account
        transaction.amount = draft.amount
        transaction.direction = draft.direction
        transaction.occurredAt = draft.occurredAt ?? message.receivedAt
        transaction.merchantRaw = merchantRaw
        transaction.merchantDisplay = merchantDisplay
        transaction.balanceAfter = draft.balanceAfter
        transaction.parseEngine = IngestionStore.engine(for: draft)
        transaction.matchedRuleID = draft.matchedRuleID
        transaction.updatedAt = now()
        if transaction.categorySource != .manual {
            let match = store.categoryMatch(for: merchantDisplay, suggestion: draft.categorySuggestion)
            transaction.category = match?.category
            transaction.categorySource = match?.source
        }

        updateCheckpoint(for: transaction, balance: draft.balanceAfter, previousAccount: previousAccount)
        store.markParsed(message, by: draft)
    }

    /// Makes the message's SMS checkpoint match the new balance.
    ///
    /// The checkpoint is looked up on the account the transaction was on before this reprocess: an
    /// SMS checkpoint always shares its transaction's account, and the person may be moving both.
    private func updateCheckpoint(for transaction: Transaction, balance: Decimal?, previousAccount: Account) {
        let transactionID = transaction.id
        let checkpoints = previousAccount.checkpoints
            .filter { $0.source == .sms && $0.sourceTransactionID == transactionID }

        guard let balance else {
            checkpoints.forEach(context.delete)
            return
        }
        if checkpoints.isEmpty {
            // The balance was observed when the message first arrived, so the checkpoint shares the
            // transaction's original instant, which already counts the transaction itself.
            context.insert(BalanceCheckpoint(
                account: transaction.account,
                amount: balance,
                recordedAt: transaction.recordedAt,
                source: .sms,
                sourceTransactionID: transactionID,
                createdAt: now()
            ))
            return
        }
        for checkpoint in checkpoints {
            checkpoint.amount = balance
            checkpoint.account = transaction.account
        }
    }

    /// Records why a reprocess failed, leaving any existing transaction untouched.
    ///
    /// A message that still has its transaction keeps its `parsed` status — the transaction is
    /// still what the archive knows about it — and only gains the error.
    private func recordFailure(
        _ diagnostics: [ParseDiagnostic],
        on message: RawMessage,
        keeping existing: Transaction?
    ) -> IngestionOutcome {
        if existing == nil {
            message.status = .failed
        }
        message.errorDescription = IngestionDiagnostics.errorDescription(of: diagnostics)
        return committed(.failed(diagnostics))
    }

    /// What the caller, the message's transaction, or the accounts say about the account.
    private enum AccountResolution {
        /// The account is known before parsing.
        case resolved(Account)
        /// The caller chose an account that is not an active one.
        case unknownChoice
        /// Several accounts could own the message; the matched rule decides.
        case undecided
    }

    /// The account the message belongs to, before parsing: the chosen one, else the existing
    /// transaction's, else the only active account.
    private func resolvedAccount(chosen accountID: UUID?, existing: Transaction?) -> AccountResolution {
        if let accountID {
            if let account = store.activeAccounts().first(where: { $0.id == accountID })
                ?? (existing?.account.id == accountID ? existing?.account : nil) {
                return .resolved(account)
            }
            return .unknownChoice
        }
        if let existing {
            return .resolved(existing.account)
        }
        let accounts = store.activeAccounts()
        return accounts.count == 1 ? .resolved(accounts[0]) : .undecided
    }

    // MARK: - Saving

    /// Saves, returning `outcome` or a storage failure after rolling back.
    private func committed(_ outcome: IngestionOutcome) -> IngestionOutcome {
        do {
            try commit()
            return outcome
        } catch {
            return .failed(diagnostics(of: outcome) + [IngestionDiagnostics.storage])
        }
    }

    private func commit() throws {
        do {
            try saveHandler(context)
        } catch {
            context.rollback()
            throw error
        }
    }

    private func diagnostics(of outcome: IngestionOutcome) -> [ParseDiagnostic] {
        if case .failed(let diagnostics) = outcome { return diagnostics }
        return []
    }

    /// Unlinks a message from its transaction so deleting the message cannot reach the transaction.
    private func detach(_ message: RawMessage) {
        message.transaction?.rawMessage = nil
        message.transaction = nil
    }

    private var store: IngestionStore {
        IngestionStore(context: context)
    }

    /// The error recorded when a parsed message no longer reads as a transaction.
    private static let keptTransactionDescription =
        "Reprocessing found no transaction in this message, so the existing transaction was kept."
}
