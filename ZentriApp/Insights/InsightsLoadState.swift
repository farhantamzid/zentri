/// How far the Insights screen's last read of the store got.
///
/// A read that threw gets its own case: a store that could not be read is not a month without
/// activity, and showing it as one would tell someone with spending that they have none.
enum InsightsLoadState: Sendable, Equatable {
    /// No read has finished yet, so the screen has nothing to draw.
    case loading
    /// The store was read; `InsightsModel.summary` describes the selected month.
    case loaded
    /// The read the screen needs threw, so there is no summary and the screen must say so.
    case failed
}
