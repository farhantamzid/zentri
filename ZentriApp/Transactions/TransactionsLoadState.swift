/// How far the Transactions list's last read of the store got.
///
/// A read that threw is its own case so a store that could not be read is never drawn as an empty
/// history, which would tell the person their messages never arrived.
enum TransactionsLoadState: Sendable, Equatable {
    /// No read has finished yet.
    case loading
    /// The store was read; an empty list means there really are no transactions.
    case loaded
    /// A read the list needs threw, so the screen offers another attempt.
    case failed
}
