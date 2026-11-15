/// How a chart's selection follows the person's finger and outlives it.
///
/// Swift Charts clears its selection binding when the finger lifts, which would take a selected
/// value's callout and button away before they could be read or tapped. The charts keep their own
/// selection instead: a touch selects what it is over, lifting keeps it, and starting a new touch
/// on the value already selected clears it.
enum ChartSelectionRule {
    /// The selection after the chart's raw selection changes.
    ///
    /// - Parameters:
    ///   - current: The selection kept so far.
    ///   - touched: What the finger is over now, or `nil` when it has lifted.
    ///   - touchBegan: Whether this change starts a touch rather than continuing a drag.
    static func selection<ID: Equatable>(current: ID?, touched: ID?, touchBegan: Bool) -> ID? {
        guard let touched else { return current }
        if touchBegan, touched == current {
            return nil
        }
        return touched
    }
}
