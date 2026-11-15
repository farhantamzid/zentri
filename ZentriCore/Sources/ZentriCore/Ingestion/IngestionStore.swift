import Foundation
import SwiftData

/// The store reads and writes ingestion and reprocessing share.
///
/// Both services turn a parse into the same rows — a parsed message, its transaction, and an
/// optional SMS checkpoint — and both decide duplicates, accounts, and categories the same way, so
/// those decisions live here once.
@MainActor
struct IngestionStore {
    let context: ModelContext

    // MARK: - Accounts

    /// The non-archived accounts, in the order an account picker shows them.
    func activeAccounts() -> [Account] {
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

    /// The account of the rule that produced `draft`, when a stored rule did.
    ///
    /// A message parsed without an account — a launch retry, or a reprocess with several accounts and
    /// no choice — lands on its matched rule's account, because rules are per account. A draft no
    /// rule produced, such as the model's, names no account.
    func ruleAccount(for draft: TransactionDraft) -> Account? {
        guard let ruleID = draft.matchedRuleID else { return nil }
        return ((try? context.fetch(FetchDescriptor<ParsingRule>())) ?? [])
            .first { $0.id == ruleID }?
            .account
    }

    // MARK: - Writing a parse

    /// Inserts the transaction a draft describes, links it to `message`, and adds an SMS checkpoint
    /// when the draft carries a balance. Nothing is saved.
    ///
    /// `recordedAt` places the transaction and its checkpoint in balance math, so it must be when the
    /// message arrived; `createdAt` is when the rows were written, which differs for a reprocess.
    ///
    /// The draft is not validated again: every engine runs ``TransactionValidator`` before it
    /// returns a ``ParseResult/transaction(_:)``.
    @discardableResult
    func insertTransaction(
        from draft: TransactionDraft,
        account: Account,
        message: RawMessage,
        recordedAt: Date,
        createdAt: Date? = nil
    ) -> Transaction {
        let createdAt = createdAt ?? recordedAt
        let merchantRaw = MessageText.collapsedWhitespace(draft.merchant)
        let merchantDisplay = MessageText.displayMerchant(from: merchantRaw)
        let match = categoryMatch(for: merchantDisplay, suggestion: draft.categorySuggestion)
        let engine = Self.engine(for: draft)

        markParsed(message, by: draft)

        let transaction = Transaction(
            account: account,
            amount: draft.amount,
            direction: draft.direction,
            occurredAt: draft.occurredAt ?? message.receivedAt,
            recordedAt: recordedAt,
            merchantRaw: merchantRaw,
            merchantDisplay: merchantDisplay,
            category: match?.category,
            categorySource: match?.source,
            balanceAfter: draft.balanceAfter,
            rawMessage: message,
            parseEngine: engine,
            matchedRuleID: draft.matchedRuleID,
            createdAt: createdAt,
            updatedAt: createdAt
        )
        context.insert(transaction)

        if let balanceAfter = draft.balanceAfter {
            // An SMS balance is the account's balance at ingestion, so the checkpoint shares the
            // transaction's instant and the transaction itself is already counted in it.
            context.insert(BalanceCheckpoint(
                account: account,
                amount: balanceAfter,
                recordedAt: recordedAt,
                source: .sms,
                sourceTransactionID: transaction.id,
                createdAt: createdAt
            ))
        }
        return transaction
    }

    /// Records on the message that `draft` parsed it.
    func markParsed(_ message: RawMessage, by draft: TransactionDraft) {
        message.status = .parsed
        message.engine = Self.engine(for: draft)
        message.matchedRuleID = draft.matchedRuleID
        message.errorDescription = nil
    }

    /// The engine a draft came from: a rule names itself, the model does not.
    static func engine(for draft: TransactionDraft) -> ParseEngine {
        draft.matchedRuleID == nil ? .foundationModels : .rules
    }

    // MARK: - Categories

    /// The category the transaction receives, looked up in the live catalog.
    ///
    /// The store never gains a category here: a match that names no stored category leaves the
    /// transaction uncategorized so the UI can show it as such.
    func categoryMatch(
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
    func isDuplicate(
        fingerprint: String,
        text: String,
        sender: String?,
        receivedAt: Date,
        accountID: UUID?,
        excluding excludedID: UUID?
    ) -> Bool {
        let byFingerprint = (try? context.fetch(FetchDescriptor<RawMessage>(
            predicate: #Predicate { $0.fingerprint == fingerprint }
        ))) ?? []
        if byFingerprint.contains(where: { $0.id != excludedID && $0.status != .failed }) {
            return true
        }

        let windowStart = receivedAt.addingTimeInterval(-Dedupe.recentDuplicateWindow)
        let windowEnd = receivedAt.addingTimeInterval(Dedupe.recentDuplicateWindow)
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
            text: text,
            sender: sender,
            accountID: accountID,
            receivedAt: receivedAt,
            existing: candidates
        )
    }
}
