import SwiftUI

/// A day's section header, which the plain list keeps pinned while its rows scroll.
struct TransactionDayHeader: View {
    let day: Date

    var body: some View {
        Text(day, format: .dateTime.weekday(.wide).day().month(.wide).year())
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Theme.secondaryInk)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("transactions.dayHeader")
    }
}
