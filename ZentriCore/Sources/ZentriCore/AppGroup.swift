/// Shared locations and file names used by the app and widget extension.
public enum AppGroup {
    /// The App Group container shared by the app and its widget extension.
    public static let identifier = "group.com.farhantamzid.zentri"
    /// The JSON snapshot the app writes for widgets to read.
    public static let widgetSnapshotFileName = "widget-snapshot.json"
    /// The JSON settings document shared through the App Group.
    public static let settingsFileName = "settings.json"
}
