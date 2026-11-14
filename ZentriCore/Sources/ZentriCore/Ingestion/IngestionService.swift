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
    /// The merchant shown when nothing is left after the message's noise is stripped.
    private static let unknownMerchant = "Unknown merchant"
    /// The largest number of trailing-noise removals tried on one merchant name.
    private static let maximumMerchantCleanupPasses = 3

    private let context: ModelContext
    private let settings: @MainActor @Sendable () -> AppSettings
    private let parserBuilder: any ParserBuilding
    private let snapshotRefresher: any WidgetSnapshotRefresher
    private let now: @Sendable () -> Date
    /// Whether the store and its sidecar files have been protected since the first save.
    private var hasProtectedStoreFiles = false

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
            .filter { $0.status == .processing }
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
    private func ingestMessage(_ request: IngestionRequest) async -> IngestionOutcome {
        let ingestedAt = now()

        let account: Account
        switch resolvedAccount(for: request) {
        case .resolved(let resolved):
            account = resolved
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
            return persist(message) ? .failed([diagnostic]) : .failed([diagnostic, Self.storageDiagnostic])
        }

        let fingerprint = Dedupe.fingerprint(
            text: request.text,
            sender: request.sender,
            accountID: account.id,
            receivedAt: request.receivedAt
        )
        if isDuplicate(fingerprint: fingerprint, request: request, accountID: account.id, excluding: nil) {
            let message = makeMessage(
                for: request,
                ingestedAt: ingestedAt,
                status: .duplicate,
                fingerprint: fingerprint
            )
            return persist(message) ? .duplicate : .failed([Self.storageDiagnostic])
        }

        let result = await parse(request, accountID: account.id)

        switch disposition(of: result) {
        case .transaction(let draft):
            let message = makeMessage(
                for: request,
                ingestedAt: ingestedAt,
                status: .parsed,
                fingerprint: fingerprint
            )
            context.insert(message)
            return persist(
                draft: draft,
                account: account,
                message: message,
                request: request,
                ingestedAt: ingestedAt,
                fingerprint: fingerprint
            )
        case .notTransaction:
            let message = makeMessage(
                for: request,
                ingestedAt: ingestedAt,
                status: .ignored,
                fingerprint: fingerprint
            )
            return persist(message) ? .notTransaction : .failed([Self.storageDiagnostic])
        case .failed(let diagnostics):
            let message = makeMessage(
                for: request,
                ingestedAt: ingestedAt,
                status: .failed,
                errorDescription: Self.errorDescription(of: diagnostics),
                fingerprint: fingerprint
            )
            return persist(message) ? .failed(diagnostics) : .failed(diagnostics + [Self.storageDiagnostic])
        case .cancelled(let diagnostics):
            // Cancelled work is retryable, never archived as a verdict on the message.
            let message = makeMessage(
                for: request,
                ingestedAt: ingestedAt,
                status: .processing,
                fingerprint: fingerprint
            )
            let surfaced = diagnostics.isEmpty ? [Self.cancelledDiagnostic] : diagnostics
            return persist(message) ? .failed(surfaced) : .failed(surfaced + [Self.storageDiagnostic])
        }
    }

    /// The retry pipeline for one existing archive row.
    private func retry(_ message: RawMessage) async -> IngestionOutcome {
        let ingestedAt = now()
        let request = IngestionRequest(
            text: message.text,
            sender: message.sender,
            receivedAt: message.receivedAt,
            accountID: nil
        )
        // A cancelled retry changes nothing, so the row is still `processing` for the next launch.
        guard !Task.isCancelled else { return .failed([Self.cancelledDiagnostic]) }

        let fingerprint = message.fingerprint
        let accounts = activeAccounts()
        let hintedAccount = accounts.count == 1 ? accounts[0] : nil

        if isDuplicate(
            fingerprint: fingerprint,
            request: request,
            accountID: hintedAccount?.id,
            excluding: message.id
        ) {
            message.status = .duplicate
            message.engine = nil
            message.matchedRuleID = nil
            message.errorDescription = nil
            return save() ? .duplicate : .failed([Self.storageDiagnostic])
        }

        // A row has no account yet, so every rule runs; the matched rule or the single active
        // account decides where the transaction lands.
        let result = await parse(request, accountID: nil)

        switch disposition(of: result) {
        case .transaction(let draft):
            guard let account = retryAccount(for: draft, among: accounts) else {
                // Nothing identifies an account, so the row stays retryable rather than guessed at.
                return .failed([Self.retryAccountDiagnostic])
            }
            return persist(
                draft: draft,
                account: account,
                message: message,
                request: request,
                ingestedAt: ingestedAt,
                fingerprint: fingerprint
            )
        case .notTransaction:
            message.status = .ignored
            message.engine = nil
            message.matchedRuleID = nil
            message.errorDescription = nil
            return save() ? .notTransaction : .failed([Self.storageDiagnostic])
        case .failed(let diagnostics):
            message.status = .failed
            message.errorDescription = Self.errorDescription(of: diagnostics)
            return save() ? .failed(diagnostics) : .failed(diagnostics + [Self.storageDiagnostic])
        case .cancelled(let diagnostics):
            // Left `processing`: the message is retried on the next launch.
            return .failed(diagnostics.isEmpty ? [Self.cancelledDiagnostic] : diagnostics)
        }
    }

    /// Parses one message with the parser the current settings ask for.
    private func parse(_ request: IngestionRequest, accountID: UUID?) async -> ParseResult {
        let appSettings = settings()
        let parser = parserBuilder.makeParser(for: appSettings.parserMode, rules: parsingRuleSpecs())
        let input = ParseInput(
            text: Self.normalizedForParsing(request.text),
            accountID: accountID,
            sender: request.sender,
            receivedAt: request.receivedAt
        )
        return await parser.parse(input)
    }

    // MARK: - Persistence

    /// Writes the parsed transaction, its message, and an optional checkpoint in one save.
    ///
    /// The message is passed in because ingestion either creates it here or reuses the row a retry
    /// is reprocessing. A save failure rolls everything back and stores the message on its own as
    /// `failed`, so no transaction is ever left half-written.
    ///
    /// The draft is not validated again: every engine runs ``TransactionValidator`` before it
    /// returns a ``ParseResult/transaction(_:)``, and a second pass here would only be a weaker copy
    /// of those checks.
    private func persist(
        draft: TransactionDraft,
        account: Account,
        message: RawMessage,
        request: IngestionRequest,
        ingestedAt: Date,
        fingerprint: String
    ) -> IngestionOutcome {
        let merchantRaw = Self.collapsedWhitespace(draft.merchant)
        let merchantDisplay = Self.displayMerchant(from: merchantRaw)
        let match = categoryMatch(for: merchantDisplay, suggestion: draft.categorySuggestion)
        let engine: ParseEngine = draft.matchedRuleID == nil ? .foundationModels : .rules

        message.status = .parsed
        message.engine = engine
        message.matchedRuleID = draft.matchedRuleID
        message.errorDescription = nil

        let transaction = Transaction(
            account: account,
            amount: draft.amount,
            direction: draft.direction,
            occurredAt: draft.occurredAt ?? message.receivedAt,
            recordedAt: ingestedAt,
            merchantRaw: merchantRaw,
            merchantDisplay: merchantDisplay,
            category: match?.category,
            categorySource: match?.source,
            balanceAfter: draft.balanceAfter,
            rawMessage: message,
            parseEngine: engine,
            matchedRuleID: draft.matchedRuleID,
            createdAt: ingestedAt,
            updatedAt: ingestedAt
        )
        let transactionID = transaction.id
        context.insert(transaction)

        if let balanceAfter = draft.balanceAfter {
            // An SMS balance is the account's balance at ingestion, so the checkpoint shares the
            // transaction's instant and the transaction itself is already counted in it.
            context.insert(BalanceCheckpoint(
                account: account,
                amount: balanceAfter,
                recordedAt: ingestedAt,
                source: .sms,
                sourceTransactionID: transactionID,
                createdAt: ingestedAt
            ))
        }

        guard save() else {
            return recordStorageFailure(for: request, ingestedAt: ingestedAt, fingerprint: fingerprint)
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
            errorDescription: Self.storageDiagnostic.message,
            fingerprint: fingerprint
        )
        persist(message)
        return .failed([Self.storageDiagnostic])
    }

    /// Saves the context, rolling back so a throw cannot leave partial rows behind.
    ///
    /// The first successful save is also where the SQLite sidecar files appear, so protection is
    /// reapplied there; a store created before any save has nothing to protect yet.
    private func save() -> Bool {
        do {
            try context.save()
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
    /// An account the Shortcut chose wins. Otherwise exactly one active account must exist; with
    /// several the message is failed rather than guessed at, because a transaction on the wrong
    /// account corrupts both balances.
    private func resolvedAccount(for request: IngestionRequest) -> AccountResolution {
        let accounts = activeAccounts()
        if let accountID = request.accountID {
            guard let account = accounts.first(where: { $0.id == accountID }) else {
                return .failed(accounts.isEmpty ? Self.addAccountDiagnostic : Self.chooseAccountDiagnostic)
            }
            return .resolved(account)
        }
        switch accounts.count {
        case 1:
            return .resolved(accounts[0])
        case 0:
            return .failed(Self.addAccountDiagnostic)
        default:
            return .failed(Self.chooseAccountDiagnostic)
        }
    }

    /// The account a retried transaction belongs to: the matched rule's, or the single active one.
    private func retryAccount(for draft: TransactionDraft, among accounts: [Account]) -> Account? {
        if let ruleID = draft.matchedRuleID,
           let rule = ((try? context.fetch(FetchDescriptor<ParsingRule>())) ?? [])
               .first(where: { $0.id == ruleID }) {
            return rule.account
        }
        return accounts.count == 1 ? accounts[0] : nil
    }

    /// The non-archived accounts, in the order an account picker shows them.
    private func activeAccounts() -> [Account] {
        let accounts = (try? context.fetch(FetchDescriptor<Account>())) ?? []
        return accounts
            .filter { $0.archivedAt == nil }
            .sorted { lhs, rhs in
                if lhs.sortOrder != rhs.sortOrder {
                    return lhs.sortOrder < rhs.sortOrder
                }
                return lhs.id.uuidString < rhs.id.uuidString
            }
    }

    /// The stored rules as parser specs, in the order the engine must evaluate them.
    ///
    /// `sorted(by:)` is not stable, so every ordering key is spelled out: priority, then creation
    /// date, then identity. Without the last two, rules that share a priority would run in whatever
    /// order the store returned them.
    private func parsingRuleSpecs() -> [ParsingRuleSpec] {
        let rules = (try? context.fetch(FetchDescriptor<ParsingRule>())) ?? []
        return rules
            .sorted { lhs, rhs in
                if lhs.priority != rhs.priority {
                    return lhs.priority < rhs.priority
                }
                if lhs.createdAt != rhs.createdAt {
                    return lhs.createdAt < rhs.createdAt
                }
                return lhs.id.uuidString < rhs.id.uuidString
            }
            .map { rule in
                ParsingRuleSpec(
                    id: rule.id,
                    accountID: rule.account.id,
                    direction: rule.direction,
                    pattern: rule.pattern,
                    dateFormat: rule.dateFormat,
                    isCaseInsensitive: rule.isCaseInsensitive,
                    dotMatchesNewlines: rule.dotMatchesNewlines,
                    priority: rule.priority,
                    isEnabled: rule.isEnabled
                )
            }
    }

    /// The category the transaction receives, looked up in the live catalog.
    ///
    /// The service never creates a category: a match that names no stored category leaves the
    /// transaction uncategorized so the UI can show it as such.
    private func categoryMatch(
        for merchant: String,
        suggestion: String?
    ) -> (category: Category, source: CategorySource)? {
        let categories = (try? context.fetch(FetchDescriptor<Category>())) ?? []
        guard !categories.isEmpty else { return nil }
        let rules = ((try? context.fetch(FetchDescriptor<CategorizationRule>())) ?? [])
            .sorted { lhs, rhs in
                if lhs.priority != rhs.priority {
                    return lhs.priority < rhs.priority
                }
                return lhs.keyword < rhs.keyword
            }
            .map { rule in
                CategorizationRuleSpec(
                    keyword: rule.keyword,
                    categoryName: rule.category.name,
                    priority: rule.priority,
                    isEnabled: rule.isEnabled
                )
            }
        let match = CategorizationService.match(
            merchant: merchant,
            rules: rules,
            suggestion: suggestion,
            categories: categories.map {
                CategorySnapshot(
                    id: $0.id,
                    name: $0.name,
                    symbolName: $0.symbolName,
                    colorToken: $0.colorToken
                )
            }
        )
        guard let category = categories.first(where: { $0.name == match.categoryName }) else {
            return nil
        }
        return (category, match.source)
    }

    // MARK: - Deduplication

    /// Whether a message is already in the archive.
    ///
    /// A failed row never blocks a new attempt: the user is re-running the automation because the
    /// message could not be read, and calling that a duplicate would hide the problem. The row being
    /// retried is excluded so a message cannot duplicate itself.
    private func isDuplicate(
        fingerprint: String,
        request: IngestionRequest,
        accountID: UUID?,
        excluding excludedID: UUID?
    ) -> Bool {
        let byFingerprint = (try? context.fetch(FetchDescriptor<RawMessage>(
            predicate: #Predicate { $0.fingerprint == fingerprint }
        ))) ?? []
        if byFingerprint.contains(where: { $0.id != excludedID && $0.status != .failed }) {
            return true
        }

        let windowStart = request.receivedAt.addingTimeInterval(-Dedupe.recentDuplicateWindow)
        let windowEnd = request.receivedAt.addingTimeInterval(Dedupe.recentDuplicateWindow)
        let nearby = (try? context.fetch(FetchDescriptor<RawMessage>(
            predicate: #Predicate { $0.receivedAt >= windowStart && $0.receivedAt <= windowEnd }
        ))) ?? []
        let candidates = nearby
            .filter { $0.id != excludedID && $0.status != .failed }
            .map { message in
                DedupeCandidate(
                    text: message.text,
                    sender: message.sender,
                    // A message's account is only recorded through its transaction; without one the
                    // account is unknown, and the sender comparison is the safer identity anyway.
                    accountID: message.transaction?.account.id,
                    receivedAt: message.receivedAt
                )
            }
        return Dedupe.isRecentDuplicate(
            text: request.text,
            sender: request.sender,
            accountID: accountID,
            receivedAt: request.receivedAt,
            existing: candidates
        )
    }

    // MARK: - Result classification

    /// What resolving an account produced.
    private enum AccountResolution {
        /// The account the transaction belongs to.
        case resolved(Account)
        /// Why no account could be chosen.
        case failed(ParseDiagnostic)
    }

    /// What a parse result means for the archive.
    private enum ParseDisposition {
        /// A validated transaction.
        case transaction(TransactionDraft)
        /// The message is not a transaction.
        case notTransaction
        /// The message could not be read; the diagnostics explain why.
        case failed([ParseDiagnostic])
        /// The caller cancelled the work, so the message must stay retryable.
        case cancelled([ParseDiagnostic])
    }

    /// Classifies a parse result, folding cancellation in.
    ///
    /// Cancellation is checked here rather than trusted to the engines: the hybrid engine collapses a
    /// cancelled rule parse into `.notTransaction` when the model finds nothing, and every
    /// diagnostic is inspected so a cancellation reported after another failure is still caught.
    private func disposition(of result: ParseResult) -> ParseDisposition {
        if Task.isCancelled {
            return .cancelled(diagnostics(from: result))
        }
        switch result {
        case .transaction(let draft):
            return .transaction(draft)
        case .notTransaction:
            return .notTransaction
        case .failure(let diagnostics):
            return diagnostics.contains { $0.code == .cancelled }
                ? .cancelled(diagnostics)
                : .failed(diagnostics)
        }
    }

    /// The diagnostics a failure carries, or none for any other result.
    private func diagnostics(from result: ParseResult) -> [ParseDiagnostic] {
        if case .failure(let diagnostics) = result {
            return diagnostics
        }
        return []
    }

    /// A user-facing error description built from diagnostics; it never contains message text.
    private static func errorDescription(of diagnostics: [ParseDiagnostic]) -> String? {
        let description = diagnostics.map(\.message).joined(separator: " ")
        return description.isEmpty ? nil : description
    }

    // MARK: - Text

    /// The text handed to the parser.
    ///
    /// Line endings are unified and the outer whitespace is trimmed, but the message's own line
    /// breaks and inner spacing stay intact so a multi-line rule still matches. The original text is
    /// what the archive keeps.
    private static func normalizedForParsing(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The text with runs of whitespace collapsed to single spaces.
    private static func collapsedWhitespace(_ value: String) -> String {
        value.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    /// The merchant for display and keyword matching, with trailing reference noise removed.
    ///
    /// A rule captures everything after its keyword, so "RM12.50 spent at KFC on 14/11/26 Ref 8891"
    /// can leave "KFC on 14/11/26 Ref 8891" as the merchant. Spec §10.2 asks for that noise to be
    /// stripped from the name the app shows and matches; the extracted value is kept on
    /// `merchantRaw` so nothing is lost. A name that is nothing but noise becomes
    /// ``unknownMerchant``.
    private static func displayMerchant(from extracted: String) -> String {
        var value = extracted
        for _ in 0..<maximumMerchantCleanupPasses {
            let stripped = trimmingTrailingSeparators(strippingTrailingNoise(value))
            if stripped == value {
                break
            }
            value = stripped
        }
        return value.isEmpty ? unknownMerchant : value
    }

    /// Removes one trailing reference or date phrase, when the value ends with one.
    private static func strippingTrailingNoise(_ value: String) -> String {
        var result = value
        for pattern in [referenceNoise, numericDateNoise, namedDateNoise] {
            guard let range = result.firstRange(of: pattern) else { continue }
            result.removeSubrange(range)
        }
        return result
    }

    /// Removes trailing punctuation that separated a merchant from the noise removed from it.
    private static func trimmingTrailingSeparators(_ value: String) -> String {
        var result = value
        while let last = result.last, ",;:.-–—".contains(last) {
            result.removeLast()
        }
        return result
    }

    /// A trailing reference such as "Ref 12345", "REF: 8891-A", or "Reference no. 77".
    private static let referenceNoise = /(?i)[\s,;:.\-–—]*\bref(?:erence)?\s*(?:no\.?|number|#|id)?\s*[:#]?\s*[A-Za-z0-9][A-Za-z0-9\-\/_]*[\s,;:.\-–—]*$/

    /// A trailing numeric date such as "on 17/11/26" or "on 2026-11-17".
    private static let numericDateNoise = /(?i)[\s,;:.\-–—]*\bon\s+\d{1,4}[.\/-]\d{1,2}[.\/-]\d{1,4}[\s,;:.\-–—]*$/

    /// A trailing named date such as "on 17 Nov 2026".
    private static let namedDateNoise = /(?i)[\s,;:.\-–—]*\bon\s+\d{1,2}(?:st|nd|rd|th)?\s+[A-Za-z]{3,9}(?:\s+\d{2,4})?[\s,;:.\-–—]*$/

    // MARK: - Diagnostics

    /// The message for a capture that names more than one possible account.
    private static let chooseAccountDiagnostic = ParseDiagnostic(
        code: .missingField,
        field: "account",
        message: "Choose an account in the Shortcut."
    )

    /// The message for a capture with no account to fall back on.
    private static let addAccountDiagnostic = ParseDiagnostic(
        code: .missingField,
        field: "account",
        message: "Add an account in Zentri before capturing messages."
    )

    /// The message for a retry that still cannot identify an account.
    private static let retryAccountDiagnostic = ParseDiagnostic(
        code: .missingField,
        field: "account",
        message: "Choose an account for this message."
    )

    /// The message for a write that could not be saved.
    ///
    /// ``ParseDiagnostic/Code`` describes parsing problems only and has no storage case, so the
    /// write failure is reported as a missing field named `storage`: something the outcome needs is
    /// absent. Adding a dedicated code would mean editing the parsing contract this task consumes.
    private static let storageDiagnostic = ParseDiagnostic(
        code: .missingField,
        field: "storage",
        message: "The message could not be saved. Try again."
    )

    /// The diagnostic reported when a parse was cancelled without one of its own.
    private static let cancelledDiagnostic = ParseDiagnostic(
        code: .cancelled,
        message: "Parsing was cancelled."
    )
}
