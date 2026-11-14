import Foundation
import SwiftData

/// Reads the stored data into the versioned document a backup file contains.
///
/// The exporter is built per backup with the settings the caller read from the settings store, because
/// settings live in the App Group's JSON document rather than in SwiftData. It never reads that store
/// or the App Group itself, and it exports only the seven stored models: the widget snapshot and the
/// insights caches are derived data that a restore rebuilds.
public struct BackupExporter: Sendable {
    /// The settings every export carries.
    private let settings: AppSettings

    /// Creates an exporter.
    ///
    /// - Parameter settings: The settings the app has now, which the backup records.
    public init(settings: AppSettings) {
        self.settings = settings
    }

    /// Reads every stored row into a document.
    ///
    /// Each collection is ordered by the model's natural key with the identity as a tiebreak, so two
    /// exports of an unchanged store produce the same rows in the same order.
    ///
    /// - Parameters:
    ///   - context: The context to read.
    ///   - appVersion: The app version to record in the document.
    /// - Returns: The document to encode.
    /// - Throws: An error when a fetch fails.
    @MainActor
    public func export(context: ModelContext, appVersion: String) throws -> BackupDocument {
        let accounts = try context.fetch(FetchDescriptor<Account>())
        let categories = try context.fetch(FetchDescriptor<Category>())
        let rawMessages = try context.fetch(FetchDescriptor<RawMessage>())
        let checkpoints = try context.fetch(FetchDescriptor<BalanceCheckpoint>())
        let parsingRules = try context.fetch(FetchDescriptor<ParsingRule>())
        let categorizationRules = try context.fetch(FetchDescriptor<CategorizationRule>())
        let transactions = try context.fetch(FetchDescriptor<Transaction>())

        return BackupDocument(
            schemaVersion: BackupCodec.currentSchemaVersion,
            appVersion: appVersion,
            exportedAt: BackupCodec.dateText(.now),
            settings: BackupSettings(settings),
            accounts: ordered(accounts, by: { ($0.sortOrder, $0.name) < ($1.sortOrder, $1.name) }, id: \.id)
                .map { account in
                    BackupAccount(
                        id: account.id,
                        name: account.name,
                        institutionName: account.institutionName,
                        sortOrder: account.sortOrder,
                        createdAt: BackupCodec.dateText(account.createdAt),
                        archivedAt: account.archivedAt.map(BackupCodec.dateText)
                    )
                },
            checkpoints: ordered(checkpoints, by: { $0.recordedAt < $1.recordedAt }, id: \.id)
                .map { checkpoint in
                    BackupCheckpoint(
                        id: checkpoint.id,
                        accountID: checkpoint.account.id,
                        amount: BackupCodec.moneyText(checkpoint.amount),
                        recordedAt: BackupCodec.dateText(checkpoint.recordedAt),
                        source: checkpoint.source,
                        sourceTransactionID: checkpoint.sourceTransactionID,
                        createdAt: BackupCodec.dateText(checkpoint.createdAt),
                        note: checkpoint.note
                    )
                },
            transactions: ordered(transactions, by: { $0.occurredAt < $1.occurredAt }, id: \.id)
                .map { transaction in
                    BackupTransaction(
                        id: transaction.id,
                        accountID: transaction.account.id,
                        amount: BackupCodec.moneyText(transaction.amount),
                        direction: transaction.direction,
                        occurredAt: BackupCodec.dateText(transaction.occurredAt),
                        recordedAt: BackupCodec.dateText(transaction.recordedAt),
                        merchantRaw: transaction.merchantRaw,
                        merchantDisplay: transaction.merchantDisplay,
                        categoryID: transaction.category?.id,
                        categorySource: transaction.categorySource,
                        balanceAfter: transaction.balanceAfter.map(BackupCodec.moneyText),
                        rawMessageID: transaction.rawMessage?.id,
                        parseEngine: transaction.parseEngine,
                        matchedRuleID: transaction.matchedRuleID,
                        isTransfer: transaction.isTransfer,
                        note: transaction.note,
                        createdAt: BackupCodec.dateText(transaction.createdAt),
                        updatedAt: BackupCodec.dateText(transaction.updatedAt)
                    )
                },
            rawMessages: ordered(rawMessages, by: { $0.receivedAt < $1.receivedAt }, id: \.id)
                .map { message in
                    BackupRawMessage(
                        id: message.id,
                        text: message.text,
                        sender: message.sender,
                        receivedAt: BackupCodec.dateText(message.receivedAt),
                        ingestedAt: BackupCodec.dateText(message.ingestedAt),
                        status: message.status,
                        engine: message.engine,
                        matchedRuleID: message.matchedRuleID,
                        errorDescription: message.errorDescription,
                        fingerprint: message.fingerprint
                    )
                },
            parsingRules: ordered(parsingRules, by: { ($0.priority, $0.createdAt) < ($1.priority, $1.createdAt) }, id: \.id)
                .map { rule in
                    BackupParsingRule(
                        id: rule.id,
                        accountID: rule.account.id,
                        name: rule.name,
                        direction: rule.direction,
                        pattern: rule.pattern,
                        dateFormat: rule.dateFormat,
                        isCaseInsensitive: rule.isCaseInsensitive,
                        dotMatchesNewlines: rule.dotMatchesNewlines,
                        priority: rule.priority,
                        isEnabled: rule.isEnabled,
                        createdAt: BackupCodec.dateText(rule.createdAt),
                        updatedAt: BackupCodec.dateText(rule.updatedAt)
                    )
                },
            categories: ordered(categories, by: { ($0.sortOrder, $0.name) < ($1.sortOrder, $1.name) }, id: \.id)
                .map { category in
                    BackupCategory(
                        id: category.id,
                        name: category.name,
                        symbolName: category.symbolName,
                        colorToken: category.colorToken,
                        sortOrder: category.sortOrder,
                        isSystem: category.isSystem
                    )
                },
            categorizationRules: ordered(
                categorizationRules,
                by: { ($0.priority, $0.keyword) < ($1.priority, $1.keyword) },
                id: \.id
            )
            .map { rule in
                BackupCategorizationRule(
                    id: rule.id,
                    keyword: rule.keyword,
                    categoryID: rule.category.id,
                    priority: rule.priority,
                    isEnabled: rule.isEnabled
                )
            }
        )
    }

    /// The rows in a stable order: the natural key first, then the identity so ties cannot reorder.
    private func ordered<Row>(
        _ rows: [Row],
        by areInIncreasingOrder: (Row, Row) -> Bool,
        id: (Row) -> UUID
    ) -> [Row] {
        rows.sorted { lhs, rhs in
            if areInIncreasingOrder(lhs, rhs) {
                return true
            }
            if areInIncreasingOrder(rhs, lhs) {
                return false
            }
            return id(lhs).uuidString < id(rhs).uuidString
        }
    }
}
