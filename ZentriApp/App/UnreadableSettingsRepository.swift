import Foundation
import Synchronization
import ZentriCore

/// A UI-test settings repository whose stored document cannot be read until it is reset or
/// replaced, which is how `-UITestUnreadableSettings` shows the recovery screen without touching
/// the real settings file.
final class UnreadableSettingsRepository: SettingsRepository, Sendable {
    /// `nil` while unreadable; after a reset or save, the stored settings (if any).
    private let state = Mutex<AppSettings??>(nil)

    func load() throws -> AppSettings? {
        try state.withLock { stored in
            guard let readable = stored else { throw CocoaError(.fileReadCorruptFile) }
            return readable
        }
    }

    func save(_ settings: AppSettings) {
        state.withLock { $0 = .some(settings) }
    }

    func remove() {
        state.withLock { $0 = .some(nil) }
    }
}
