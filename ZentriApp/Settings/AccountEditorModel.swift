import Foundation
import Observation

/// The account editor's fields and validation: a new account with its opening balance, or an
/// existing account's name and institution.
@MainActor
@Observable
final class AccountEditorModel {
    /// Whether the editor adds an account, which is when it asks for an opening balance.
    let isCreating: Bool
    /// The account's name.
    var name: String
    /// The optional institution.
    var institutionName: String
    /// The opening balance as typed; ``openingBalance`` parses it.
    var openingBalanceText = ""
    /// The locale whose separators the decimal pad offers and the balance is read with.
    private let locale: Locale

    /// - Parameters:
    ///   - account: The account to edit, or `nil` to add one.
    ///   - locale: The locale typed balances are read with. A test passes one to fix the separators.
    init(account: AccountListItem?, locale: Locale = .current) {
        isCreating = account == nil
        name = account?.name ?? ""
        institutionName = account?.institutionName ?? ""
        self.locale = locale
    }

    /// The opening balance, when the typed text is a number.
    var openingBalance: Decimal? {
        DecimalInput.decimal(from: openingBalanceText, locale: locale)
    }

    /// Whether Save can be offered: a name, and for a new account an opening balance of zero or more.
    var canSave: Bool {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        guard isCreating else { return true }
        guard let openingBalance else { return false }
        return openingBalance >= 0
    }
}
