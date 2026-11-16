import Foundation
import ZentriCore

extension ParseDiagnostic {
    /// The diagnostic in the reader's language.
    ///
    /// Core diagnostics carry English text for logs and the archive; the app shows its own localized
    /// explanation chosen by the code, and by the field where one code covers several problems.
    var localizedMessage: LocalizedStringResource {
        switch code {
        case .inputTooLong: "The message is too long to read."
        case .invalidPattern: "The rule's pattern isn't a valid regular expression."
        case .missingAmountGroup: "The rule's pattern has no amount group."
        case .missingField: missingFieldMessage
        case .invalidAmount: "The captured amount isn't a number Zentri can read."
        case .amountNotPositive: "The amount must be greater than zero."
        case .dateTooFarInFuture: "The date is more than a day after the message arrived."
        case .missingMerchant: "The merchant is missing."
        case .matchFailed: "The rule's pattern couldn't be run on this message."
        case .modelUnavailable: "Apple Intelligence isn't available right now."
        case .modelFailed:
            field == "language"
                ? "Apple Intelligence can't read messages in this language yet."
                : "Apple Intelligence couldn't read this message."
        case .modelTimedOut: "Apple Intelligence took too long and was stopped."
        case .cancelled: "Reading the message was cancelled."
        }
    }

    /// One code covers missing captures, accounts, and storage, so the field tells them apart.
    private var missingFieldMessage: LocalizedStringResource {
        switch field {
        case "account": "Choose an account for this message."
        case "storage": "Zentri couldn't save the result. Try again."
        case "amount": "The rule matched but captured no amount."
        default: "Something the message needs is missing."
        }
    }
}
