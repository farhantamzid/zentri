/// How far the dashboard's last read of the store got.
///
/// A read that threw gets its own case rather than being folded into a missing summary: a store
/// that could not be read is not a store with no account, and the two states offer opposite advice.
enum OverviewLoadState: Sendable, Equatable {
    /// No read has finished yet, so the screen has nothing to draw.
    case loading
    /// The store was read. `OverviewModel.summary` is `nil` only when no active account exists.
    case loaded
    /// A read the dashboard needs threw, so there is no summary and the screen must say so.
    case failed
}
