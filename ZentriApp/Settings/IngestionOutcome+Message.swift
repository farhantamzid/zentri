import Foundation
import ZentriCore

extension IngestionOutcome {
    /// What a reprocess tells the person.
    var reprocessMessage: LocalizedStringResource {
        switch self {
        case .transaction: "The message was read and its transaction is up to date."
        case .duplicate: "This message repeats one that's already stored, so no transaction was added."
        case .notTransaction: "The message doesn't describe a transaction. Nothing was changed."
        case .failed(let diagnostics):
            diagnostics.first?.localizedMessage ?? "The message still couldn't be read."
        }
    }

    /// Whether the reprocess produced a transaction.
    var isTransaction: Bool {
        if case .transaction = self { return true }
        return false
    }

    /// Whether the reprocess failed only because the account is ambiguous.
    var needsAccountChoice: Bool {
        if case .failed(let diagnostics) = self {
            return diagnostics.contains { $0.code == .missingField && $0.field == "account" }
        }
        return false
    }
}
