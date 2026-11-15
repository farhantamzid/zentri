import UIKit

/// One background task's identifier, ended at most once — by the work finishing or by expiry.
@MainActor
final class BackgroundTaskToken {
    var identifier = UIBackgroundTaskIdentifier.invalid

    func end() {
        guard identifier != .invalid else { return }
        UIApplication.shared.endBackgroundTask(identifier)
        identifier = .invalid
    }
}
