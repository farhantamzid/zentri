import Foundation
import Synchronization
import ZentriCore

/// A settings repository that lives only in memory, for UI tests and previews.
///
/// `-UITestMode` must never touch the App Group or the real settings file, so the app swaps the
/// file store for this one. The lock keeps the value safe because the repository is `Sendable`
/// while its storage is mutated.
final class InMemorySettingsRepository: SettingsRepository, Sendable {
    private let state = Mutex<AppSettings?>(nil)

    func load() -> AppSettings? {
        state.withLock { $0 }
    }

    func save(_ settings: AppSettings) {
        state.withLock { $0 = settings }
    }

    /// Clears the stored settings, matching the removal of the settings file.
    func clear() {
        state.withLock { $0 = nil }
    }
}
