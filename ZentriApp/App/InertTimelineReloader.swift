/// A reloader that does nothing, for UI tests, which must never touch the real widgets.
struct InertTimelineReloader: WidgetTimelineReloading {
    func reloadAllTimelines() {}
}
