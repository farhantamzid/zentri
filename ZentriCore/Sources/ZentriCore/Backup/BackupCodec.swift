import Foundation

/// Encodes and decodes the versioned JSON document a backup is.
///
/// The format is deliberately plain: sorted keys so the same data always serializes the same way,
/// plain decimal strings for money, ISO-8601 strings for dates, and no derived data. Decoding is
/// strict about the whole document — the schema version, identities, references, amounts, dates, and
/// account checkpoints are all checked — so a caller only ever receives a document that can be
/// imported without leaving the store half-written.
public enum BackupCodec {
    /// The document format version this app writes and reads.
    public static let currentSchemaVersion = 1

    /// The locale that decides how a decimal string is read, whatever the device is set to.
    private static let decimalLocale = Locale(identifier: "en_US_POSIX")

    /// Encodes a document as the JSON a backup file contains.
    ///
    /// - Parameter document: The document to write, normally one built by ``BackupExporter``.
    /// - Returns: The file's bytes.
    /// - Throws: An encoding error when the document cannot be encoded.
    public static func encode(_ document: BackupDocument) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(document)
    }

    /// Decodes and validates a backup file.
    ///
    /// - Parameter data: The file's bytes.
    /// - Returns: The document the file describes.
    /// - Throws: ``BackupError/invalidFile(reason:)`` when the bytes are not a document this app can
    ///   read, or another ``BackupError`` when the document decodes but does not validate.
    public static func decode(_ data: Data) throws -> BackupDocument {
        let document: BackupDocument
        do {
            document = try JSONDecoder().decode(BackupDocument.self, from: data)
        } catch let error as DecodingError {
            throw BackupError.invalidFile(reason: reason(for: error))
        } catch {
            throw BackupError.invalidFile(reason: error.localizedDescription)
        }
        try document.validate()
        return document
    }

    /// A readable reason for a decode failure, without any of the file's contents.
    private static func reason(for error: DecodingError) -> String {
        func location(_ context: DecodingError.Context) -> String {
            let path = context.codingPath.map(\.stringValue).filter { !$0.isEmpty }.joined(separator: ".")
            return path.isEmpty ? context.debugDescription : "\(path): \(context.debugDescription)"
        }
        switch error {
        case .dataCorrupted(let context):
            return "the JSON is not readable (\(location(context)))"
        case .keyNotFound(let key, let context):
            return "the key '\(key.stringValue)' is missing (\(location(context)))"
        case .typeMismatch(_, let context):
            return location(context)
        case .valueNotFound(_, let context):
            return location(context)
        @unknown default:
            return "the document has an unexpected shape"
        }
    }
}

// MARK: - Amounts and dates as text

extension BackupCodec {
    /// A decimal amount as the plain, locale-independent string a backup stores.
    ///
    /// `NSDecimalNumber` writes a `-` sign and a `.` separator whatever the device's locale is, and it
    /// never uses exponent notation, which is what makes the text portable between devices.
    ///
    /// - Parameter value: The amount to write.
    /// - Returns: The amount's text, e.g. `-12.5`.
    static func moneyText(_ value: Decimal) -> String {
        NSDecimalNumber(decimal: value).stringValue
    }

    /// An instant as the ISO-8601 string a backup stores, with fractional seconds.
    ///
    /// - Parameter date: The instant to write.
    /// - Returns: The instant's text in UTC, e.g. `2026-11-18T11:06:40.000Z`.
    static func dateText(_ date: Date) -> String {
        fractionalDateFormatter.string(from: date)
    }

    /// The formatter for the fractional form a backup writes, built once.
    ///
    /// A store holds tens of thousands of dates, and building an `ISO8601DateFormatter` for each one
    /// cost seconds per backup. The formatter is never mutated after it is built, and
    /// `ISO8601DateFormatter` is safe to use from several threads at once.
    nonisolated(unsafe) private static let fractionalDateFormatter = makeDateFormatter(
        [.withInternetDateTime, .withFractionalSeconds]
    )

    /// The formatter for the whole-second form other tools write, built once.
    nonisolated(unsafe) private static let wholeSecondDateFormatter = makeDateFormatter([.withInternetDateTime])

    /// A UTC ISO-8601 formatter with `options`.
    private static func makeDateFormatter(_ options: ISO8601DateFormatter.Options) -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = options
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }

    /// The exact decimal an amount's text denotes.
    ///
    /// Only the plain form a backup writes is accepted — an optional `-`, digits, and an optional
    /// `.` with digits. A grouped, `+`-signed, exponent, or partly decimal string is refused instead
    /// of being silently truncated by the parser.
    ///
    /// - Parameters:
    ///   - value: The text to read.
    ///   - field: Where the text came from, for the error.
    /// - Returns: The decimal value.
    /// - Throws: ``BackupError/malformedDecimal(field:value:)`` when the text is not a plain decimal.
    static func decimal(from value: String, field: String) throws -> Decimal {
        guard isPlainDecimal(value), let decimal = Decimal(string: value, locale: decimalLocale) else {
            throw BackupError.malformedDecimal(field: field, value: value)
        }
        return decimal
    }

    /// The instant a date's text denotes.
    ///
    /// Both the fractional form this app writes and the whole-second form other tools produce are
    /// accepted.
    ///
    /// - Parameters:
    ///   - value: The text to read.
    ///   - field: Where the text came from, for the error.
    /// - Returns: The instant.
    /// - Throws: ``BackupError/malformedDate(field:value:)`` when the text is not an ISO-8601 instant.
    static func date(from value: String, field: String) throws -> Date {
        for formatter in [fractionalDateFormatter, wholeSecondDateFormatter] {
            if let date = formatter.date(from: value) {
                return date
            }
        }
        throw BackupError.malformedDate(field: field, value: value)
    }

    /// The document path of a row's field, for an error that names where a defect is.
    ///
    /// - Parameters:
    ///   - kind: The collection the row belongs to, e.g. "transactions".
    ///   - id: The row's identity.
    ///   - name: The field's name, e.g. "amount".
    static func fieldPath(_ kind: String, _ id: UUID, _ name: String) -> String {
        "\(kind)[\(id.uuidString)].\(name)"
    }

    /// Whether the text is a plain decimal: an optional `-`, digits, and an optional fraction.
    private static func isPlainDecimal(_ value: String) -> Bool {
        let bytes = value.utf8
        var index = bytes.startIndex
        if index < bytes.endIndex, bytes[index] == UInt8(ascii: "-") {
            bytes.formIndex(after: &index)
        }
        var digitCount = 0
        while index < bytes.endIndex, bytes[index] >= UInt8(ascii: "0"), bytes[index] <= UInt8(ascii: "9") {
            digitCount += 1
            bytes.formIndex(after: &index)
        }
        guard digitCount > 0 else { return false }
        if index < bytes.endIndex, bytes[index] == UInt8(ascii: ".") {
            bytes.formIndex(after: &index)
            var fractionCount = 0
            while index < bytes.endIndex, bytes[index] >= UInt8(ascii: "0"), bytes[index] <= UInt8(ascii: "9") {
                fractionCount += 1
                bytes.formIndex(after: &index)
            }
            guard fractionCount > 0 else { return false }
        }
        return index == bytes.endIndex
    }
}

// MARK: - Validation

extension BackupDocument {
    /// Checks the whole document before a caller trusts it.
    ///
    /// Both entry points share this check: ``BackupCodec/decode(_:)`` runs it so a file is rejected
    /// before it reaches an importer, and ``BackupImporter/import(document:into:mode:)`` runs it again
    /// because a document built in memory is just as untrusted as a file. Nothing is mutated until it
    /// passes.
    ///
    /// Only required relationships are checked. A `matchedRuleID` names a rule that may have been
    /// deleted since the message was parsed, so it is a weak reference and never makes a document
    /// invalid.
    ///
    /// - Throws: ``BackupError`` describing the first defect found.
    func validate() throws {
        guard schemaVersion == BackupCodec.currentSchemaVersion else {
            throw BackupError.unsupportedVersion(found: schemaVersion)
        }
        try validateIdentities()
        try validateAmountsAndDates()
        try validateReferences()
        try validateAccountCheckpoints()
    }

    /// Rejects two rows that claim the same identity, whichever kinds of row they are.
    private func validateIdentities() throws {
        var identities = Set<UUID>()
        func register(_ id: UUID) throws {
            guard identities.insert(id).inserted else {
                throw BackupError.duplicateID(id)
            }
        }
        for account in accounts { try register(account.id) }
        for checkpoint in checkpoints { try register(checkpoint.id) }
        for transaction in transactions { try register(transaction.id) }
        for message in rawMessages { try register(message.id) }
        for rule in parsingRules { try register(rule.id) }
        for category in categories { try register(category.id) }
        for rule in categorizationRules { try register(rule.id) }
    }

    /// Rejects an amount or a date that does not read back exactly.
    private func validateAmountsAndDates() throws {
        _ = try BackupCodec.date(from: exportedAt, field: "exportedAt")
        if let lastBackupAt = settings.lastBackupAt {
            _ = try BackupCodec.date(from: lastBackupAt, field: "settings.lastBackupAt")
        }

        for account in accounts {
            try requireDate(account.createdAt, "accounts", account.id, "createdAt")
            if let archivedAt = account.archivedAt {
                try requireDate(archivedAt, "accounts", account.id, "archivedAt")
            }
        }

        for checkpoint in checkpoints {
            try requireAmount(checkpoint.amount, "checkpoints", checkpoint.id, "amount")
            try requireDate(checkpoint.recordedAt, "checkpoints", checkpoint.id, "recordedAt")
            try requireDate(checkpoint.createdAt, "checkpoints", checkpoint.id, "createdAt")
        }

        for transaction in transactions {
            try requireAmount(transaction.amount, "transactions", transaction.id, "amount")
            if let balanceAfter = transaction.balanceAfter {
                try requireAmount(balanceAfter, "transactions", transaction.id, "balanceAfter")
            }
            try requireDate(transaction.occurredAt, "transactions", transaction.id, "occurredAt")
            try requireDate(transaction.recordedAt, "transactions", transaction.id, "recordedAt")
            try requireDate(transaction.createdAt, "transactions", transaction.id, "createdAt")
            try requireDate(transaction.updatedAt, "transactions", transaction.id, "updatedAt")
        }

        for message in rawMessages {
            try requireDate(message.receivedAt, "rawMessages", message.id, "receivedAt")
            try requireDate(message.ingestedAt, "rawMessages", message.id, "ingestedAt")
        }

        for rule in parsingRules {
            try requireDate(rule.createdAt, "parsingRules", rule.id, "createdAt")
            try requireDate(rule.updatedAt, "parsingRules", rule.id, "updatedAt")
        }
    }

    /// Rejects a row whose required relationship names a record the document does not contain.
    private func validateReferences() throws {
        let accountIDs = Set(accounts.map(\.id))
        let transactionIDs = Set(transactions.map(\.id))
        let categoryIDs = Set(categories.map(\.id))
        let rawMessageIDs = Set(rawMessages.map(\.id))

        for checkpoint in checkpoints {
            try requireReference(checkpoint.accountID, in: accountIDs, "checkpoints", checkpoint.id, "accountID")
            if let sourceTransactionID = checkpoint.sourceTransactionID {
                try requireReference(
                    sourceTransactionID,
                    in: transactionIDs,
                    "checkpoints",
                    checkpoint.id,
                    "sourceTransactionID"
                )
            }
        }

        for transaction in transactions {
            try requireReference(transaction.accountID, in: accountIDs, "transactions", transaction.id, "accountID")
            if let categoryID = transaction.categoryID {
                try requireReference(categoryID, in: categoryIDs, "transactions", transaction.id, "categoryID")
            }
            if let rawMessageID = transaction.rawMessageID {
                try requireReference(rawMessageID, in: rawMessageIDs, "transactions", transaction.id, "rawMessageID")
            }
        }

        for rule in parsingRules {
            try requireReference(rule.accountID, in: accountIDs, "parsingRules", rule.id, "accountID")
        }

        for rule in categorizationRules {
            try requireReference(rule.categoryID, in: categoryIDs, "categorizationRules", rule.id, "categoryID")
        }
    }

    /// Rejects an account that no checkpoint anchors, because its balance would be unknown.
    private func validateAccountCheckpoints() throws {
        let accountsWithCheckpoints = Set(checkpoints.map(\.accountID))
        for account in accounts where !accountsWithCheckpoints.contains(account.id) {
            throw BackupError.accountWithoutCheckpoint(account.id)
        }
    }

    /// Rejects an amount that does not read back exactly.
    private func requireAmount(_ value: String, _ kind: String, _ rowID: UUID, _ name: String) throws {
        _ = try BackupCodec.decimal(from: value, field: BackupCodec.fieldPath(kind, rowID, name))
    }

    /// Rejects a date that does not read back exactly.
    private func requireDate(_ value: String, _ kind: String, _ rowID: UUID, _ name: String) throws {
        _ = try BackupCodec.date(from: value, field: BackupCodec.fieldPath(kind, rowID, name))
    }

    /// Fails when `id` is not one of the document's `known` identities.
    private func requireReference(
        _ id: UUID,
        in known: Set<UUID>,
        _ kind: String,
        _ rowID: UUID,
        _ name: String
    ) throws {
        guard known.contains(id) else {
            throw BackupError.brokenReference(field: BackupCodec.fieldPath(kind, rowID, name), id: id)
        }
    }
}
