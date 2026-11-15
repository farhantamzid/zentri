import SwiftUI
import ZentriCore

/// One currency in the picker: its code and symbol, with the currency's name in the person's language.
struct CurrencyOptionLabel: View {
    let code: String

    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(verbatim: "\(code)  \(CurrencyCatalog.symbol(for: code))")
                .foregroundStyle(Theme.ink)
            if let name = locale.localizedString(forCurrencyCode: code) {
                Text(name)
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryInk)
            }
        }
    }
}
