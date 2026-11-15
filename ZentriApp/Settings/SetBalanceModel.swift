import Foundation
import Observation

/// The "Set balance" sheet's fields and validation.
///
/// The date can range from the account's newest checkpoint to now: anything earlier would never be
/// the checkpoint the balance is computed from, so the number typed would not show.
@MainActor
@Observable
final class SetBalanceModel {
    /// The balance as typed; ``amount`` parses it.
    var amountText = ""
    /// When the balance was true.
    var date: Date
    /// The dates the picker offers.
    let dateRange: ClosedRange<Date>
    /// The locale whose separators the decimal pad offers and the balance is read with.
    private let locale: Locale

    /// - Parameters:
    ///   - latestCheckpoint: When the account's newest balance was recorded, if it has one.
    ///   - now: The latest date the picker offers, which is also where it starts.
    ///   - locale: The locale typed balances are read with.
    init(latestCheckpoint: Date?, now: Date = .now, locale: Locale = .current) {
        let earliest = min(latestCheckpoint ?? .distantPast, now)
        dateRange = earliest...now
        date = now
        self.locale = locale
    }

    /// The balance, when the typed text is a number.
    var amount: Decimal? {
        DecimalInput.decimal(from: amountText, locale: locale)
    }

    /// Whether Save can be offered: a balance of zero or more on an allowed date.
    var canSave: Bool {
        guard let amount else { return false }
        return amount >= 0 && dateRange.contains(date)
    }
}
