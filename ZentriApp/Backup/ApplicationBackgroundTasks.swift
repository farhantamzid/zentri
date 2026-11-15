import UIKit

/// Background time from `UIApplication`, so a backup started as the app leaves the screen can
/// finish.
///
/// If the time runs out first the task is ended; the snapshot write is atomic, so the folder then
/// holds either the previous snapshot or the new one, never part of a file.
@MainActor
struct ApplicationBackgroundTasks: BackgroundTaskRunning {
    func run(named name: String, _ work: @escaping @MainActor () async -> Void) {
        let task = BackgroundTaskToken()
        task.identifier = UIApplication.shared.beginBackgroundTask(withName: name) {
            task.end()
        }
        Task {
            await work()
            task.end()
        }
    }
}
