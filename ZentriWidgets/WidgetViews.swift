import Charts
import SwiftUI
import WidgetKit
import ZentriCore

/// The app's palette, read from the asset catalog the app and its widgets share.
///
/// It mirrors the app's `Theme` colors by name, since the extension cannot import app code. Every
/// color has light, dark, and high-contrast variants. In the tinted and clear Home Screen modes the
/// system recolors them, so nothing relies on color alone: categories also carry a symbol and a name.
enum WidgetPalette {
    static let canvas = Color("Canvas")
    static let ink = Color("Ink")
    static let secondaryInk = Color("SecondaryInk")
    static let accent = Color("AccentColor")
    static let income = Color("Income")
    static let spending = Color("Spending")

    /// The color for a category's token, falling back to slate as the app does.
    static func category(_ token: String) -> Color {
        switch token.lowercased() {
        case "green", "coral", "teal", "violet", "amber", "cyan", "indigo": Color(token.lowercased())
        default: Color("slate")
        }
    }
}

/// The frame every Home Screen Zentri widget shares: its background, its deep link, and the
/// placeholder treatment.
///
/// When the model is the placeholder — no snapshot could be read — the content is redacted and an
/// "Open Zentri" hint sits over it, and VoiceOver hears only the hint, not the sample values behind
/// the redaction.
struct WidgetFrame<Content: View>: View {
    private let model: WidgetDisplayModel
    private let link: DeepLink
    private let content: Content

    init(model: WidgetDisplayModel, link: DeepLink, @ContentBuilder content: () -> Content) {
        self.model = model
        self.link = link
        self.content = content()
    }

    var body: some View {
        Group {
            if model.isPlaceholder {
                content
                    .redacted(reason: .placeholder)
                    .accessibilityHidden(true)
                    .overlay {
                        OpenZentriHint()
                    }
            } else {
                content
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(for: .widget) {
            WidgetPalette.canvas
        }
        .widgetURL(model.isPlaceholder ? DeepLink.overview.url : link.url)
    }
}

/// The hint drawn over a placeholder widget.
struct OpenZentriHint: View {
    var body: some View {
        Label {
            Text("Open Zentri", comment: "Shown on a widget that has no data yet; opening the app writes it.")
        } icon: {
            Image(systemName: "arrow.up.forward.app")
        }
        .font(.footnote.bold())
        .foregroundStyle(WidgetPalette.ink)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(WidgetPalette.canvas, in: .capsule)
        .widgetAccentable()
        .unredacted()
    }
}

/// An amount from the display model, with tabular digits, marked privacy-sensitive so the system
/// can redact it on a locked device.
struct WidgetAmountText: View {
    private let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(verbatim: text)
            .monospacedDigit()
            .lineLimit(1)
            .privacySensitive()
    }
}

/// A titled figure, such as "Spent today" over its amount, read by VoiceOver as one element.
///
/// The title is the label and the amount the value; a hidden amount is announced as "Hidden" rather
/// than as a row of dots. Apply the amount's font and color from outside; the title keeps its own.
struct WidgetFigure: View {
    private let title: LocalizedStringResource
    private let amount: String
    private let isHidden: Bool
    private let alignment: HorizontalAlignment

    init(
        _ title: LocalizedStringResource,
        amount: String,
        isHidden: Bool,
        alignment: HorizontalAlignment = .leading
    ) {
        self.title = title
        self.amount = amount
        self.isHidden = isHidden
        self.alignment = alignment
    }

    var body: some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(title)
                .font(.footnote)
                .foregroundStyle(WidgetPalette.secondaryInk)
                .lineLimit(1)
            WidgetAmountText(amount)
                .minimumScaleFactor(0.4)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(title))
        .accessibilityValue(isHidden ? Text(WidgetStrings.hiddenAmount) : Text(verbatim: amount))
    }
}

/// Strings more than one widget speaks.
enum WidgetStrings {
    /// Spoken in place of an amount the widget hides.
    static let hiddenAmount = LocalizedStringResource(
        "Hidden",
        comment: "VoiceOver in place of an amount the widget hides for privacy."
    )
}

/// A category's symbol in its palette color.
struct WidgetCategoryIcon: View {
    private let symbolName: String
    private let colorToken: String

    /// A fixed width keeps names aligned however wide each symbol is; it grows with Dynamic Type.
    @ScaledMetric(relativeTo: .footnote) private var width = 20.0

    init(symbolName: String, colorToken: String) {
        self.symbolName = symbolName
        self.colorToken = colorToken
    }

    var body: some View {
        Image(systemName: symbolName)
            .font(.footnote)
            .foregroundStyle(WidgetPalette.category(colorToken))
            .frame(width: width)
            .widgetAccentable()
            .accessibilityHidden(true)
    }
}

/// A line explaining that a widget has nothing to chart or list yet.
struct WidgetEmptyMessage: View {
    private let message: LocalizedStringResource

    init(_ message: LocalizedStringResource) {
        self.message = message
    }

    var body: some View {
        Text(message)
            .font(.footnote)
            .foregroundStyle(WidgetPalette.secondaryInk)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .multilineTextAlignment(.center)
    }
}

/// The daily spend bars. Bar heights are kept when amounts are hidden; only the figures are hidden.
struct TrendChart: View {
    let bars: [WidgetDisplayModel.TrendBar]

    var body: some View {
        Chart(bars, id: \.date) { bar in
            BarMark(
                x: .value("Day", bar.date, unit: .day),
                y: .value("Spent", bar.spend),
                width: .ratio(0.6)
            )
            .foregroundStyle(WidgetPalette.accent)
            .cornerRadius(2)
        }
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 2)) { _ in
                AxisGridLine()
            }
        }
        .widgetAccentable()
    }
}

/// One recent transaction: category symbol, merchant, and signed amount.
///
/// The row is one VoiceOver element that says whether the money arrived or left, since the sign and
/// the income color are not something a listener hears; a hidden amount is spoken as "Hidden".
struct RecentTransactionWidgetRow: View {
    let row: WidgetDisplayModel.RecentRow
    let amountsHidden: Bool
    /// Whether the category's name shows under the merchant, when there is room for it.
    let showsCategory: Bool

    var body: some View {
        HStack {
            WidgetCategoryIcon(symbolName: row.symbolName, colorToken: row.colorToken)
            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: row.merchant)
                    .font(.subheadline)
                    .foregroundStyle(WidgetPalette.ink)
                    .lineLimit(1)
                if showsCategory {
                    Text(verbatim: row.categoryName)
                        .font(.caption)
                        .foregroundStyle(WidgetPalette.secondaryInk)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 4)
            WidgetAmountText(row.amount)
                .font(.subheadline)
                .foregroundStyle(row.isCredit ? WidgetPalette.income : WidgetPalette.ink)
                .layoutPriority(1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spokenSummary)
    }

    /// Merchant, category, and the movement in words.
    private var spokenSummary: Text {
        let amount = amountsHidden ? String(localized: WidgetStrings.hiddenAmount) : row.spokenAmount
        return if row.isCredit {
            Text(
                "\(row.merchant), \(row.categoryName), received \(amount)",
                comment: "VoiceOver for a widget row of money that arrived: merchant, category, then the amount or “Hidden”."
            )
        } else {
            Text(
                "\(row.merchant), \(row.categoryName), spent \(amount)",
                comment: "VoiceOver for a widget row of money that left: merchant, category, then the amount or “Hidden”."
            )
        }
    }
}

/// The top categories' shares of this month's spend as one bar.
///
/// Each segment is as wide as its category's share; the rest of the track is spend outside the
/// listed categories, so a capped list never looks like the whole month.
struct CategoryShareBar: View {
    let rows: [WidgetDisplayModel.CategoryRow]

    var body: some View {
        Chart(rows) { row in
            BarMark(x: .value("Share", row.share))
                .foregroundStyle(WidgetPalette.category(row.colorToken))
        }
        .chartXScale(domain: 0...1)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartPlotStyle { plot in
            plot
                .background(.quaternary)
                .clipShape(.capsule)
        }
        .frame(height: 10)
        .widgetAccentable()
        .accessibilityHidden(true)
    }
}

/// One top category: symbol, name, share, and — when there is room — its amount.
struct CategoryWidgetRow: View {
    let row: WidgetDisplayModel.CategoryRow
    let amountsHidden: Bool
    /// Whether the amount shows beside the share.
    let showsAmount: Bool

    var body: some View {
        HStack {
            WidgetCategoryIcon(symbolName: row.symbolName, colorToken: row.colorToken)
            Text(verbatim: row.name)
                .font(.subheadline)
                .foregroundStyle(WidgetPalette.ink)
                .lineLimit(1)
            Spacer(minLength: 4)
            if showsAmount {
                WidgetAmountText(row.amount)
                    .font(.subheadline)
                    .foregroundStyle(WidgetPalette.ink)
                    .layoutPriority(1)
            }
            Text(row.share, format: .percent.precision(.fractionLength(0)))
                .font(.footnote)
                .monospacedDigit()
                .foregroundStyle(WidgetPalette.secondaryInk)
                .layoutPriority(1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spokenSummary)
    }

    /// Name, share, and — when shown — the amount or "Hidden".
    private var spokenSummary: Text {
        let share = row.share.formatted(.percent.precision(.fractionLength(0)))
        guard showsAmount else {
            return Text(
                "\(row.name), \(share) of spending",
                comment: "VoiceOver for a widget category: its name, then its share of this month's spending."
            )
        }
        let amount = amountsHidden ? String(localized: WidgetStrings.hiddenAmount) : row.amount
        return Text(
            "\(row.name), \(amount), \(share) of spending",
            comment: "VoiceOver for a widget category: name, amount or “Hidden”, then its share of this month's spending."
        )
    }
}
