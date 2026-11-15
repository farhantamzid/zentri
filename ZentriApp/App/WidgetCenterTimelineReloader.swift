import WidgetKit

/// Reloads the widgets through `WidgetCenter`.
struct WidgetCenterTimelineReloader: WidgetTimelineReloading {
    func reloadAllTimelines() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}
