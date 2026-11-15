import Foundation
import SwiftData
import ZentriCore

/// What the Shortcut says after a capture.
///
/// A transaction is described by its amount, in the person's currency and grouping, and its merchant.
/// Every other outcome says what happened to the message, so a person reading a notification can
/// tell a duplicate from a failure without opening the app.
@MainActor
struct CaptureSMSDialog {
    /// Where the new transaction is read back from.
    let context: ModelContext
    /// The person's currency and grouping, in the reader's locale.
    let format: MoneyFormat

    /// The dialog for one outcome.
    func message(for outcome: IngestionOutcome) -> LocalizedStringResource {
        switch outcome {
        case .transaction(let id):
            transactionMessage(id: id)
        case .duplicate:
            LocalizedStringResource(
                "This message is already in Zentri, so nothing was added.",
                comment: "Shortcut dialog: the captured message repeats one that is already stored."
            )
        case .notTransaction:
            LocalizedStringResource(
                "This message isn't a transaction, so nothing was added.",
                comment: "Shortcut dialog: the captured message is a code, promotion, or other non-transaction."
            )
        case .failed(let diagnostics):
            failureMessage(for: diagnostics)
        }
    }

    /// "Recorded $12.50 at KFC." for spending, "Recorded $2,500.00 from Acme." for income.
    private func transactionMessage(id: UUID) -> LocalizedStringResource {
        let descriptor = FetchDescriptor<ZentriCore.Transaction>(predicate: #Predicate { $0.id == id })
        guard let transaction = try? context.fetch(descriptor).first else {
            return LocalizedStringResource(
                "Recorded the transaction.",
                comment: "Shortcut dialog: a transaction was saved but could not be read back to describe it."
            )
        }
        let amount = format.currencyString(from: transaction.amount)
        let merchant = transaction.merchantDisplay
        switch transaction.direction {
        case .debit:
            return LocalizedStringResource(
                "Recorded \(amount) at \(merchant).",
                comment: "Shortcut dialog after spending is captured. The first %@ is the amount with its currency, the second the merchant."
            )
        case .credit:
            return LocalizedStringResource(
                "Recorded \(amount) from \(merchant).",
                comment: "Shortcut dialog after income is captured. The first %@ is the amount with its currency, the second the payer."
            )
        }
    }

    /// Why the capture did not produce a transaction, and where the message went.
    ///
    /// A cancelled capture is not a failure: the message is stored as `processing` and the next launch
    /// finishes it, so the dialog says exactly that.
    private func failureMessage(for diagnostics: [ParseDiagnostic]) -> LocalizedStringResource {
        func has(field: String) -> Bool {
            diagnostics.contains { $0.code == .missingField && $0.field == field }
        }

        if has(field: CaptureSMSDiagnostics.setupField) {
            return LocalizedStringResource(
                "Open Zentri to finish setup.",
                comment: "Shortcut dialog when a message arrives before onboarding is finished."
            )
        }
        if has(field: CaptureSMSDiagnostics.textField) {
            return LocalizedStringResource(
                "The Shortcut didn't pass any message text. Set SMS Text to the message's content.",
                comment: "Shortcut dialog when the automation passed empty text. SMS Text is the action's parameter name."
            )
        }
        if has(field: "storage") {
            return LocalizedStringResource(
                "Zentri couldn't save this message. Try again.",
                comment: "Shortcut dialog when the store could not be written."
            )
        }
        if diagnostics.contains(where: { $0.code == .cancelled }) {
            return LocalizedStringResource(
                "The message was saved and will finish when Zentri opens.",
                comment: "Shortcut dialog when reading the message was interrupted; the app retries it on launch."
            )
        }
        if has(field: "account") {
            return LocalizedStringResource(
                "Zentri couldn't tell which account this message belongs to. Add a rule for it, or choose an account in the Shortcut. It's saved in the message inbox.",
                comment: "Shortcut dialog when several accounts exist, the Shortcut chose none, and no rule matched; or the chosen account is unavailable."
            )
        }
        let reason = diagnostics.first.map { String(localized: $0.localizedMessage) }
            ?? String(localized: "The message couldn't be read.")
        return LocalizedStringResource(
            "Zentri couldn't read this message. \(reason) It's saved in the message inbox.",
            comment: "Shortcut dialog when parsing failed. %@ is a sentence explaining why."
        )
    }
}
