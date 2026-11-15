import Foundation
import Observation
import SwiftData
import ZentriCore

/// The Shortcuts setup guide's ingestion health: the Overview card's summary of the message archive.
///
/// A read that throws is ``SettingsLoadState/failed``, never an archive where nothing has failed.
@MainActor
@Observable
final class ShortcutsSetupModel {
    /// How far the last read got.
    private(set) var loadState = SettingsLoadState.loading
    /// The archive's health, once read.
    private(set) var health: IngestionHealth?

    @ObservationIgnored private let fetchMessages: @MainActor () throws -> [RawMessage]

    /// Creates the model over the supplied context.
    convenience init(context: ModelContext) {
        self.init(fetchMessages: { try context.fetch(FetchDescriptor<RawMessage>()) })
    }

    /// Creates the model over a supplied read, which is how a test makes the read throw.
    init(fetchMessages: @escaping @MainActor () throws -> [RawMessage]) {
        self.fetchMessages = fetchMessages
    }

    /// Reads the archive again.
    func refresh() {
        do {
            health = IngestionHealth(messages: try fetchMessages())
            loadState = .loaded
        } catch {
            health = nil
            loadState = .failed
        }
    }
}
