import Foundation
import SwiftData

/// What an import did, counted per kind of row.
public struct ImportSummary: Equatable, Sendable {
    /// How many rows of each kind an import handled.
    public struct RowCounts: Equatable, Sendable {
        /// Accounts.
        public var accounts: Int
        /// Balance checkpoints.
        public var checkpoints: Int
        /// Transactions.
        public var transactions: Int
        /// Raw messages.
        public var rawMessages: Int
        /// Regex parsing rules.
        public var parsingRules: Int
        /// Categories.
        public var categories: Int
        /// Keyword categorization rules.
        public var categorizationRules: Int

        public init(
            accounts: Int = 0,
            checkpoints: Int = 0,
            transactions: Int = 0,
            rawMessages: Int = 0,
            parsingRules: Int = 0,
            categories: Int = 0,
            categorizationRules: Int = 0
        ) {
            self.accounts = accounts
            self.checkpoints = checkpoints
            self.transactions = transactions
            self.rawMessages = rawMessages
            self.parsingRules = parsingRules
            self.categories = categories
            self.categorizationRules = categorizationRules
        }

        /// The total number of rows across every kind.
        public var total: Int {
            accounts + checkpoints + transactions + rawMessages + parsingRules + categories + categorizationRules
        }
    }

    /// The mode the import ran in.
    public let mode: ImportMode
    /// The rows the import wrote.
    public let created: RowCounts
    /// The rows the import left alone because the store already had them.
    public let skipped: RowCounts

    public init(mode: ImportMode, created: RowCounts, skipped: RowCounts) {
        self.mode = mode
        self.created = created
        self.skipped = skipped
    }
}

/// Applies a backup document to a store.
///
/// Both modes validate the whole document before they touch anything, so an invalid file can never
/// change existing data. ``ImportMode/replace`` swaps the store's rows for the document's in one save
/// and rolls back if that save fails; ``ImportMode/merge`` only creates rows the store is missing and
/// never updates one it already has. Neither mode writes settings: they live in the App Group's
/// settings document, which the caller owns and applies itself when it wants a full restore.
///
/// The importer saves the context, so call it with no unsaved changes of your own.
@MainActor
public struct BackupImporter {
    /// The save both modes go through, replaceable so a test can make persistence fail.
    ///
    /// Production leaves this at `ModelContext.save()`. The seam exists because a failed save is the
    /// only way to prove an import leaves the existing data in place, and no real store can be made to
    /// fail on demand. It is internal, so only the test target can replace it.
    internal var saveHandler: (ModelContext) throws -> Void = { try $0.save() }

    /// Creates an importer.
    public init() {}

    /// Imports a document.
    ///
    /// - Parameters:
    ///   - document: The document to apply. It is validated here even when it came from
    ///     ``BackupCodec/decode(_:)``, because a document built in memory is just as untrusted.
    ///   - context: The context to write; for replace, the context whose rows are replaced.
    ///   - mode: Whether to replace the store's rows or merge into them.
    /// - Returns: Counts of what was created and what was skipped.
    /// - Throws: A ``BackupError`` when the document is invalid, or the save error after a rollback.
    public func `import`(document: BackupDocument, into context: ModelContext, mode: ImportMode) throws -> ImportSummary {
        try document.validate()
        switch mode {
        case .replace:
            return try replace(document, in: context)
        case .merge:
            return try merge(document, in: context)
        }
    }

    // MARK: - Replace

    /// Replaces every stored row with the document's rows.
    ///
    /// Every row is built and parsed before the first stored row is deleted, and the swap is saved
    /// once; a failure rolls the context back, which leaves the store's previous data in place.
    private func replace(_ document: BackupDocument, in context: ModelContext) throws -> ImportSummary {
        do {
            let accounts = try document.accounts.map(makeAccount)
            let categories = document.categories.map(makeCategory)
            let rawMessages = try document.rawMessages.map(makeRawMessage)
            let accountsByID = keyed(accounts, id: \.id)
            let categoriesByID = keyed(categories, id: \.id)
            let rawMessagesByID = keyed(rawMessages, id: \.id)
            let checkpoints = try document.checkpoints.map { row in
                try makeCheckpoint(row, accounts: accountsByID)
            }
            let parsingRules = try document.parsingRules.map { row in
                try makeParsingRule(row, accounts: accountsByID)
            }
            let categorizationRules = try document.categorizationRules.map { row in
                try makeCategorizationRule(row, categories: categoriesByID)
            }
            let transactions = try document.transactions.map { row in
                try makeTransaction(
                    row,
                    accounts: accountsByID,
                    categories: categoriesByID,
                    rawMessages: rawMessagesByID
                )
            }

            try deleteAll(Transaction.self, in: context)
            try deleteAll(BalanceCheckpoint.self, in: context)
            try deleteAll(RawMessage.self, in: context)
            try deleteAll(ParsingRule.self, in: context)
            try deleteAll(CategorizationRule.self, in: context)
            try deleteAll(Account.self, in: context)
            try deleteAll(Category.self, in: context)

            for account in accounts { context.insert(account) }
            for category in categories { context.insert(category) }
            for rawMessage in rawMessages { context.insert(rawMessage) }
            for checkpoint in checkpoints { context.insert(checkpoint) }
            for rule in parsingRules { context.insert(rule) }
            for rule in categorizationRules { context.insert(rule) }
            for transaction in transactions { context.insert(transaction) }

            try saveHandler(context)
            return ImportSummary(
                mode: .replace,
                created: counts(of: document),
                skipped: ImportSummary.RowCounts()
            )
        } catch {
            context.rollback()
            throw error
        }
    }

    // MARK: - Merge

    /// Creates the rows the store is missing and leaves every row it already has untouched.
    ///
    /// Accounts, checkpoints, categories, and rules are matched by identity. A transaction is skipped
    /// when its identity is stored, and a raw message is skipped when its identity or its fingerprint
    /// is stored; a skipped message's identity is still mapped onto the stored row, so a new
    /// transaction can link to the message that is already there.
    private func merge(_ document: BackupDocument, in context: ModelContext) throws -> ImportSummary {
        do {
            var accountsByID = keyed(try context.fetch(FetchDescriptor<Account>()), id: \.id)
            var categoriesByID = keyed(try context.fetch(FetchDescriptor<Category>()), id: \.id)
            let storedMessages = try context.fetch(FetchDescriptor<RawMessage>())
            var rawMessagesByID = keyed(storedMessages, id: \.id)
            var rawMessagesByFingerprint = Dictionary(
                storedMessages.map { ($0.fingerprint, $0) },
                uniquingKeysWith: { first, _ in first }
            )
            let storedCheckpoints = Set(try context.fetch(FetchDescriptor<BalanceCheckpoint>()).map(\.id))
            let storedParsingRules = Set(try context.fetch(FetchDescriptor<ParsingRule>()).map(\.id))
            let storedCategorizationRules = Set(try context.fetch(FetchDescriptor<CategorizationRule>()).map(\.id))
            let storedTransactions = Set(try context.fetch(FetchDescriptor<Transaction>()).map(\.id))

            var created = ImportSummary.RowCounts()
            var skipped = ImportSummary.RowCounts()

            for row in document.accounts {
                if accountsByID[row.id] != nil {
                    skipped.accounts += 1
                } else {
                    let account = try makeAccount(row)
                    context.insert(account)
                    accountsByID[row.id] = account
                    created.accounts += 1
                }
            }

            for row in document.categories {
                if categoriesByID[row.id] != nil {
                    skipped.categories += 1
                } else {
                    let category = makeCategory(row)
                    context.insert(category)
                    categoriesByID[row.id] = category
                    created.categories += 1
                }
            }

            for row in document.rawMessages {
                if let stored = rawMessagesByID[row.id] ?? rawMessagesByFingerprint[row.fingerprint] {
                    rawMessagesByID[row.id] = stored
                    skipped.rawMessages += 1
                } else {
                    let rawMessage = try makeRawMessage(row)
                    context.insert(rawMessage)
                    rawMessagesByID[row.id] = rawMessage
                    rawMessagesByFingerprint[row.fingerprint] = rawMessage
                    created.rawMessages += 1
                }
            }

            for row in document.checkpoints {
                if storedCheckpoints.contains(row.id) {
                    skipped.checkpoints += 1
                } else {
                    context.insert(try makeCheckpoint(row, accounts: accountsByID))
                    created.checkpoints += 1
                }
            }

            for row in document.parsingRules {
                if storedParsingRules.contains(row.id) {
                    skipped.parsingRules += 1
                } else {
                    context.insert(try makeParsingRule(row, accounts: accountsByID))
                    created.parsingRules += 1
                }
            }

            for row in document.categorizationRules {
                if storedCategorizationRules.contains(row.id) {
                    skipped.categorizationRules += 1
                } else {
                    context.insert(try makeCategorizationRule(row, categories: categoriesByID))
                    created.categorizationRules += 1
                }
            }

            for row in document.transactions {
                if storedTransactions.contains(row.id) {
                    skipped.transactions += 1
                } else {
                    context.insert(
                        try makeTransaction(
                            row,
                            accounts: accountsByID,
                            categories: categoriesByID,
                            rawMessages: rawMessagesByID
                        )
                    )
                    created.transactions += 1
                }
            }

            try saveHandler(context)
            return ImportSummary(mode: .merge, created: created, skipped: skipped)
        } catch {
            context.rollback()
            throw error
        }
    }

    // MARK: - Rows

    /// Builds an account from its document row.
    private func makeAccount(_ row: BackupAccount) throws -> Account {
        let createdAt = try BackupCodec.date(
            from: row.createdAt, field: BackupCodec.fieldPath("accounts", row.id, "createdAt")
        )
        let archivedAt = try row.archivedAt.map { value in
            try BackupCodec.date(from: value, field: BackupCodec.fieldPath("accounts", row.id, "archivedAt"))
        }
        return Account(
            id: row.id,
            name: row.name,
            institutionName: row.institutionName,
            sortOrder: row.sortOrder,
            createdAt: createdAt,
            archivedAt: archivedAt
        )
    }

    /// Builds a category from its document row.
    private func makeCategory(_ row: BackupCategory) -> Category {
        Category(
            id: row.id,
            name: row.name,
            symbolName: row.symbolName,
            colorToken: row.colorToken,
            sortOrder: row.sortOrder,
            isSystem: row.isSystem
        )
    }

    /// Builds a raw message from its document row.
    private func makeRawMessage(_ row: BackupRawMessage) throws -> RawMessage {
        let receivedAt = try BackupCodec.date(
            from: row.receivedAt, field: BackupCodec.fieldPath("rawMessages", row.id, "receivedAt")
        )
        let ingestedAt = try BackupCodec.date(
            from: row.ingestedAt, field: BackupCodec.fieldPath("rawMessages", row.id, "ingestedAt")
        )
        return RawMessage(
            id: row.id,
            text: row.text,
            sender: row.sender,
            receivedAt: receivedAt,
            ingestedAt: ingestedAt,
            status: row.status,
            engine: row.engine,
            matchedRuleID: row.matchedRuleID,
            errorDescription: row.errorDescription,
            fingerprint: row.fingerprint
        )
    }

    /// Builds a checkpoint from its document row and the accounts already resolved.
    private func makeCheckpoint(_ row: BackupCheckpoint, accounts: [UUID: Account]) throws -> BalanceCheckpoint {
        let amount = try BackupCodec.decimal(
            from: row.amount, field: BackupCodec.fieldPath("checkpoints", row.id, "amount")
        )
        let recordedAt = try BackupCodec.date(
            from: row.recordedAt, field: BackupCodec.fieldPath("checkpoints", row.id, "recordedAt")
        )
        let createdAt = try BackupCodec.date(
            from: row.createdAt, field: BackupCodec.fieldPath("checkpoints", row.id, "createdAt")
        )
        let account = try resolveAccount(
            row.accountID, in: accounts, field: BackupCodec.fieldPath("checkpoints", row.id, "accountID")
        )
        return BalanceCheckpoint(
            id: row.id,
            account: account,
            amount: amount,
            recordedAt: recordedAt,
            source: row.source,
            sourceTransactionID: row.sourceTransactionID,
            createdAt: createdAt,
            note: row.note
        )
    }

    /// Builds a parsing rule from its document row and the accounts already resolved.
    private func makeParsingRule(_ row: BackupParsingRule, accounts: [UUID: Account]) throws -> ParsingRule {
        let createdAt = try BackupCodec.date(
            from: row.createdAt, field: BackupCodec.fieldPath("parsingRules", row.id, "createdAt")
        )
        let updatedAt = try BackupCodec.date(
            from: row.updatedAt, field: BackupCodec.fieldPath("parsingRules", row.id, "updatedAt")
        )
        let account = try resolveAccount(
            row.accountID, in: accounts, field: BackupCodec.fieldPath("parsingRules", row.id, "accountID")
        )
        return ParsingRule(
            id: row.id,
            account: account,
            name: row.name,
            direction: row.direction,
            pattern: row.pattern,
            dateFormat: row.dateFormat,
            isCaseInsensitive: row.isCaseInsensitive,
            dotMatchesNewlines: row.dotMatchesNewlines,
            priority: row.priority,
            isEnabled: row.isEnabled,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    /// Builds a categorization rule from its document row and the categories already resolved.
    private func makeCategorizationRule(
        _ row: BackupCategorizationRule,
        categories: [UUID: Category]
    ) throws -> CategorizationRule {
        let category = try resolveCategory(
            row.categoryID, in: categories, field: BackupCodec.fieldPath("categorizationRules", row.id, "categoryID")
        )
        return CategorizationRule(
            id: row.id,
            keyword: row.keyword,
            category: category,
            priority: row.priority,
            isEnabled: row.isEnabled
        )
    }

    /// Builds a transaction from its document row and the rows already resolved.
    private func makeTransaction(
        _ row: BackupTransaction,
        accounts: [UUID: Account],
        categories: [UUID: Category],
        rawMessages: [UUID: RawMessage]
    ) throws -> Transaction {
        let amount = try BackupCodec.decimal(
            from: row.amount, field: BackupCodec.fieldPath("transactions", row.id, "amount")
        )
        let balanceAfter = try row.balanceAfter.map { value in
            try BackupCodec.decimal(
                from: value, field: BackupCodec.fieldPath("transactions", row.id, "balanceAfter")
            )
        }
        let occurredAt = try BackupCodec.date(
            from: row.occurredAt, field: BackupCodec.fieldPath("transactions", row.id, "occurredAt")
        )
        let recordedAt = try BackupCodec.date(
            from: row.recordedAt, field: BackupCodec.fieldPath("transactions", row.id, "recordedAt")
        )
        let createdAt = try BackupCodec.date(
            from: row.createdAt, field: BackupCodec.fieldPath("transactions", row.id, "createdAt")
        )
        let updatedAt = try BackupCodec.date(
            from: row.updatedAt, field: BackupCodec.fieldPath("transactions", row.id, "updatedAt")
        )
        let account = try resolveAccount(
            row.accountID, in: accounts, field: BackupCodec.fieldPath("transactions", row.id, "accountID")
        )
        let category = try row.categoryID.map { id in
            try resolveCategory(
                id, in: categories, field: BackupCodec.fieldPath("transactions", row.id, "categoryID")
            )
        }
        let rawMessage = try row.rawMessageID.map { id in
            try resolveRawMessage(
                id, in: rawMessages, field: BackupCodec.fieldPath("transactions", row.id, "rawMessageID")
            )
        }
        return Transaction(
            id: row.id,
            account: account,
            amount: amount,
            direction: row.direction,
            occurredAt: occurredAt,
            recordedAt: recordedAt,
            merchantRaw: row.merchantRaw,
            merchantDisplay: row.merchantDisplay,
            category: category,
            categorySource: row.categorySource,
            balanceAfter: balanceAfter,
            rawMessage: rawMessage,
            parseEngine: row.parseEngine,
            matchedRuleID: row.matchedRuleID,
            isTransfer: row.isTransfer,
            note: row.note,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    // MARK: - Lookups

    /// The account `id` names, which validation has already established exists.
    private func resolveAccount(_ id: UUID, in accounts: [UUID: Account], field: String) throws -> Account {
        guard let account = accounts[id] else {
            throw BackupError.brokenReference(field: field, id: id)
        }
        return account
    }

    /// The category `id` names, which validation has already established exists.
    private func resolveCategory(
        _ id: UUID,
        in categories: [UUID: Category],
        field: String
    ) throws -> Category {
        guard let category = categories[id] else {
            throw BackupError.brokenReference(field: field, id: id)
        }
        return category
    }

    /// The raw message `id` names, which validation has already established exists.
    private func resolveRawMessage(_ id: UUID, in rawMessages: [UUID: RawMessage], field: String) throws -> RawMessage {
        guard let rawMessage = rawMessages[id] else {
            throw BackupError.brokenReference(field: field, id: id)
        }
        return rawMessage
    }

    /// The rows keyed by their identity.
    private func keyed<Row>(_ rows: [Row], id: (Row) -> UUID) -> [UUID: Row] {
        Dictionary(rows.map { (id($0), $0) }, uniquingKeysWith: { first, _ in first })
    }

    // MARK: - Helpers

    /// The rows the document describes, counted per kind.
    private func counts(of document: BackupDocument) -> ImportSummary.RowCounts {
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

    /// Deletes every stored row of a kind.
    private func deleteAll<Row: PersistentModel>(_ type: Row.Type, in context: ModelContext) throws {
        for row in try context.fetch(FetchDescriptor<Row>()) {
            context.delete(row)
        }
    }
}
