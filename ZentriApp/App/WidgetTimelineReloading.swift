/// Asks WidgetKit to redraw the widgets after the snapshot they read has changed.
///
/// It is a seam so tests can count reloads and `-UITestMode` can make them do nothing; only
/// ``WidgetCenterTimelineReloader`` talks to WidgetKit.
protocol WidgetTimelineReloading: Sendable {
    /// Asks every widget for a new timeline.
    @MainActor func reloadAllTimelines()
}
