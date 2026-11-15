import ZentriCore

/// The one path by which the app changes what its widgets show: it rewrites or removes the widget
/// snapshot, then reloads every widget timeline when that changed what the widgets draw.
///
/// It is the app's ``WidgetSnapshotRefresher``: every mutation service, ingestion, the Shortcuts
/// capture, and a settings change already await `refresh()`, so none of them calls WidgetKit
/// itself. Ingestion refreshes after every message, including one-time passwords and duplicates, and
/// WidgetKit budgets background reloads, so a refresh reloads only when the snapshot it wrote shows
/// something different from the one stored before it (``WidgetSnapshot/showsSameContent(as:)``).
/// "Delete All Data" goes through ``removeSnapshot()``, which always reloads, so a widget never
/// keeps drawing a balance that was erased.
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

    /// Rewrites the snapshot from the store, then reloads the widgets if what they show changed.
    ///
    /// "Before" is the snapshot file as it stands just before this write — on the first refresh
    /// after launch, whatever the previous run left — because that file is what the widgets are
    /// drawing. A write that failed leaves the file as it was, so it reloads nothing.
    func refresh() async {
        let before = store.read()
        await refresher.refresh()
        let after = store.read()
        let unchanged = switch (before, after) {
        case (nil, nil): true
        case let (before?, after?): before.showsSameContent(as: after)
        default: false
        }
        if !unchanged {
            timelineReloader.reloadAllTimelines()
        }
    }

    /// Deletes the snapshot, then reloads the widgets so they draw their placeholder.
    func removeSnapshot() throws {
        try store.remove()
        timelineReloader.reloadAllTimelines()
    }
}
