import Foundation
import ZentriCore

/// A model client that always reports the on-device model as unavailable.
///
/// UI tests run with it so the tester's "AI unavailable" status does not depend on whether the
/// simulator has Apple Intelligence; it never parses anything.
struct UnavailableModelClient: TransactionModelClient {
    func availability() async -> ModelAvailability {
        .unavailable(String(localized: "Apple Intelligence isn't available on this device."))
    }

    func parse(text: String) async throws -> ModelTransactionOutput {
        ModelTransactionOutput(isTransaction: false)
    }
}
