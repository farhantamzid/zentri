import ZentriCore

/// The one path by which the app changes what its widgets show: it rewrites or removes the widget
/// snapshot, then reloads every widget timeline.
///
/// It is the app's ``WidgetSnapshotRefresher``: every mutation service, ingestion, the Shortcuts
/// capture, and a settings change already await `refresh()`, so each of them reloads the widgets
/// without calling WidgetKit itself. "Delete All Data" goes through ``removeSnapshot()``, so a
/// widget never keeps drawing a balance that was erased.
@MainActor
struct WidgetSnapshotPublisher: WidgetSnapshotRefresher {
    private let refresher: any WidgetSnapshotRefresher
    private let store: any WidgetSnapshotStore
    private let timelineReloader: any WidgetTimelineReloading

    /// - Parameters:
    ///   - refresher: What writes the snapshot, normally ``LiveWidgetSnapshotRefresher``.
    ///   - store: The store `refresher` writes to, which ``removeSnapshot()`` empties.
    ///   - timelineReloader: What tells WidgetKit; inert under `-UITestMode`.
    init(
        refresher: any WidgetSnapshotRefresher,
        store: any WidgetSnapshotStore,
        timelineReloader: any WidgetTimelineReloading
    ) {
        self.refresher = refresher
        self.store = store
        self.timelineReloader = timelineReloader
    }

    /// Rewrites the snapshot from the store, then reloads the widgets.
    ///
    /// The reload follows even when the write failed: the widgets then read the file they can, or
    /// fall back to their placeholder, which is still the most current thing they can show.
    func refresh() async {
        await refresher.refresh()
        timelineReloader.reloadAllTimelines()
    }

    /// Deletes the snapshot, then reloads the widgets so they draw their placeholder.
    func removeSnapshot() throws {
        try store.remove()
        timelineReloader.reloadAllTimelines()
    }
}
