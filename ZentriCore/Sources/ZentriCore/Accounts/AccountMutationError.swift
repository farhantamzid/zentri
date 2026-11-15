/// Why ``AccountMutationService`` refused a change before writing anything.
public enum AccountMutationError: Error, Equatable, Sendable {
    /// The account's name was blank.
    case missingName
    /// The balance was below zero. v1 accounts are bank accounts without credit semantics, the same
    /// rule onboarding applies to the first opening balance.
    case negativeBalance
    /// The balance was dated after now, which would hide every transaction recorded before that date.
    case balanceDateInFuture
    /// The balance was dated before the account's newest checkpoint, so it would never be the one the
    /// balance is computed from and the displayed balance would not change.
    case balanceDateBeforeLatestCheckpoint
}
