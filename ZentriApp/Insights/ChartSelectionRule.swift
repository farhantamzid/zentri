/// How a chart's selection follows the person's finger and outlives it.
///
/// Swift Charts clears its selection binding when the finger lifts, which would take a selected
/// value's callout and button away before they could be read or tapped. The charts keep their own
/// selection instead: a touch selects what it is over, and lifting keeps it. Touching never clears a
/// selection — a press and the tap that may end it can both report the same touch, and a toggle
/// would let the second undo the first — so a chart clears its selection by its own explicit means,
/// and a new month starts with none.
enum ChartSelectionRule {
    /// The selection after the chart's raw selection changes.
    ///
    /// - Parameters:
    ///   - current: The selection kept so far.
    ///   - touched: What the finger is over now, or `nil` when it has lifted.
    static func selection<ID: Equatable>(current: ID?, touched: ID?) -> ID? {
        touched ?? current
    }
}
