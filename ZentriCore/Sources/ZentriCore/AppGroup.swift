import Foundation

/// Shared locations and file names used by the app and widget extension.
public enum AppGroup {
    /// The App Group container shared by the app and its widget extension.
    public static let identifier = "group.com.farhantamzid.zentri"
    /// The JSON snapshot the app writes for widgets to read.
    public static let widgetSnapshotFileName = "widget-snapshot.json"
    /// The JSON settings document shared through the App Group.
    public static let settingsFileName = "settings.json"
}

/// The App Group's directory and the files in it.
///
/// The app and its widget extension are separate processes that only meet inside the shared
/// container. Every URL here is optional: an App Group the process cannot reach — a missing
/// entitlement, a simulator without the group, a macOS build without provisioning — yields `nil` so
/// the app and the widgets can show their setup message instead of crashing on a path that does not
/// exist.
public enum SharedContainer {
    /// The App Group container directory, or `nil` when this process cannot reach it.
    public static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier)
    }

    /// The widget snapshot file, or `nil` when the App Group is unavailable.
    public static var widgetSnapshotURL: URL? {
        containerURL?.appending(path: AppGroup.widgetSnapshotFileName)
    }

    /// The settings document, or `nil` when the App Group is unavailable.
    public static var settingsURL: URL? {
        containerURL?.appending(path: AppGroup.settingsFileName)
    }
}
