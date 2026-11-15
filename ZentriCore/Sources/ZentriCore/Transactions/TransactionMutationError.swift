/// Why ``TransactionMutationService`` refused an edit before writing anything.
public enum TransactionMutationError: Error, Equatable, Sendable {
    /// The amount was zero or negative; the direction carries the sign.
    case invalidAmount
    /// The account the edit names does not exist.
    case missingAccount
    /// The merchant was blank.
    case missingMerchant
    /// The category the edit names does not exist.
    case missingCategory
}
