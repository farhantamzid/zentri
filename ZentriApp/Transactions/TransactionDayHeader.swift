import SwiftUI
import ZentriCore

/// A day's heading over its group: "TODAY · Tue 17 Nov" on the left and the day's net on the right.
struct TransactionDayHeader: View {
    let day: Date
    var items: [TransactionListItem] = []

    @Environment(\.moneyFormat) private var moneyFormat

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            HStack(spacing: 0) {
                Text(title.localizedUppercase)
                    .fontWeight(.semibold)
                    .kerning(0.4)
                Text(verbatim: " · \(subtitle)")
            }
            .lineLimit(1)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(day, format: .dateTime.weekday(.wide).day().month(.wide).year()))
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("transactions.dayHeader")
            Spacer()
            if !items.isEmpty {
                Text(moneyFormat.signedCurrencyString(from: net))
                    .monospacedDigit()
                    .accessibilityLabel(Text("Net \(moneyFormat.signedCurrencyString(from: net))"))
            }
        }
        .font(.footnote)
        .foregroundStyle(Theme.secondaryInk)
        .textCase(nil)
        .padding(.horizontal, Theme.Spacing.xs)
    }

    private var net: Decimal {
        items.reduce(Decimal.zero) { $0 + $1.signedAmount }
    }

    private var title: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return String(localized: "Today") }
        if calendar.isDateInYesterday(day) { return String(localized: "Yesterday") }
        return day.formatted(.dateTime.weekday(.wide))
    }

    private var subtitle: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) || calendar.isDateInYesterday(day) {
            return day.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
        }
        let sameYear = calendar.isDate(day, equalTo: .now, toGranularity: .year)
        return day.formatted(sameYear ? .dateTime.day().month(.abbreviated) : .dateTime.day().month(.abbreviated).year())
    }
}
