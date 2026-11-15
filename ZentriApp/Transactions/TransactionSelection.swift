import Foundation
import ZentriCore

/// The transaction whose detail is open, resolved when the row was tapped.
///
/// Everything the sheet needs is captured here, so presenting it never reads the stored
/// transaction again — which matters once the detail has deleted it.
struct TransactionSelection: Identifiable {
    let id: UUID
    let transaction: ZentriCore.Transaction
    /// The name of the parsing rule that produced the transaction, when it can be found.
    let matchedRuleName: String?
}
