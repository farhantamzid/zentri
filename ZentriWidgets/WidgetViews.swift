import Charts
import UIKit
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
    /// The faintest text, as the app's `Theme.tertiaryInk`.
    static let tertiaryInk = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0x8C / 255, green: 0x84 / 255, blue: 0x7A / 255, alpha: 1)
            : UIColor(red: 0xA8 / 255, green: 0x9F / 255, blue: 0x94 / 255, alpha: 1)
    })
    /// The two ambient lights behind the widget, as the app's background draws them.
    static let ambientTeal = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0x0F / 255, green: 0x6B / 255, blue: 0x66 / 255, alpha: 1)
            : UIColor(red: 0x9E / 255, green: 0xD9 / 255, blue: 0xCF / 255, alpha: 1)
    })
    static let ambientPeach = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0x6B / 255, green: 0x42 / 255, blue: 0x22 / 255, alpha: 1)
            : UIColor(red: 0xF3 / 255, green: 0xC9 / 255, blue: 0xA0 / 255, alpha: 1)
    })

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
            WidgetBackground()
        }
        .widgetURL(model.isPlaceholder ? DeepLink.overview.url : link.url)
    }
}

/// The app's warm canvas with its two soft lights — teal at the top leading corner, peach at the
/// bottom trailing one — so a widget reads as part of the app. In the tinted and clear Home Screen
/// modes the system replaces the container background, so the lights only show in full color.
struct WidgetBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let strength = colorScheme == .dark ? 0.32 : 0.55
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                WidgetPalette.canvas
                light(WidgetPalette.ambientTeal, strength: strength, radius: max(size.width, size.height) * 0.75)
                    .position(x: 0, y: 0)
                light(WidgetPalette.ambientPeach, strength: strength, radius: max(size.width, size.height) * 0.7)
                    .position(x: size.width, y: size.height)
            }
        }
    }

    private func light(_ color: Color, strength: Double, radius: CGFloat) -> some View {
        Circle()
            .fill(RadialGradient(
                colors: [color.opacity(strength), color.opacity(strength * 0.4), color.opacity(0)],
                center: .center,
                startRadius: 0,
                endRadius: radius
            ))
            .frame(width: radius * 2, height: radius * 2)
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
/// The title is the label and the amount the value; a hidden or privacy-redacted amount is announced
/// as "Hidden" rather than as a row of dots or the amount the redaction covers. Apply the amount's font and color from outside; the title keeps its own.
struct WidgetFigure: View {
    private let title: LocalizedStringResource
    private let amount: String
    private let isHidden: Bool
    private let alignment: HorizontalAlignment

    @Environment(\.redactionReasons) private var redactionReasons

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
                .font(.caption)
                .foregroundStyle(WidgetPalette.secondaryInk)
                .lineLimit(1)
            WidgetAmountText(amount)
                .minimumScaleFactor(0.4)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(title))
        .accessibilityValue(Text(verbatim: WidgetStrings.spokenAmount(
            amount,
            amountsHidden: isHidden,
            redactionReasons: redactionReasons
        )))
    }
}

/// Strings more than one widget speaks.
enum WidgetStrings {
    /// Spoken in place of an amount the widget hides.
    static let hiddenAmount = LocalizedStringResource(
        "Hidden",
        comment: "VoiceOver in place of an amount the widget hides for privacy."
    )

    /// What VoiceOver says for an amount: the amount, or "Hidden" when the widget hides amounts or
    /// the system is redacting privacy-sensitive content, as on a locked device. An accessibility
    /// label or value is separate text that the visible redaction does not reach, so every spoken
    /// amount goes through here.
    static func spokenAmount(_ amount: String, amountsHidden: Bool, redactionReasons: RedactionReasons) -> String {
        WidgetDisplayModel.spokenAmount(
            amount,
            amountsHidden: amountsHidden,
            privacyRedacted: redactionReasons.contains(.privacy)
        ) ?? String(localized: hiddenAmount)
    }
}

/// A category's filled symbol on a soft square of its color, as the app's rows draw it.
///
/// In the tinted and clear Home Screen modes the system draws the tile in a single tint, so the
/// category's name beside it carries the meaning.
struct WidgetCategoryIcon: View {
    private let symbolName: String
    private let colorToken: String

    /// The tile grows with Dynamic Type so the symbol never crowds its square.
    @ScaledMetric(relativeTo: .footnote) private var side = 26.0
    @Environment(\.colorScheme) private var colorScheme

    init(symbolName: String, colorToken: String) {
        self.symbolName = symbolName
        self.colorToken = colorToken
    }

    var body: some View {
        let color = WidgetPalette.category(colorToken)
        Image(systemName: symbolName)
            .symbolVariant(.fill)
            .font(.system(size: side * 0.52, weight: .medium))
            .foregroundStyle(color)
            .frame(width: side, height: side)
            .background(
                color.opacity(colorScheme == .dark ? 0.2 : 0.14),
                in: .rect(cornerRadius: side * 0.3, style: .continuous)
            )
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

/// The daily spend bars, newest on the right and picked out in the accent; the others are quiet.
/// Bar heights are kept when amounts are hidden; only the figures are hidden.
///
/// Plain shapes rather than a chart: a widget renders once per timeline entry, and rounded bars
/// are all the design draws.
struct TrendChart: View {
    let bars: [WidgetDisplayModel.TrendBar]

    var body: some View {
        let highest = bars.map(\.spend).max() ?? 0
        let spacing: CGFloat = bars.count > 14 ? 2 : 5
        GeometryReader { proxy in
            HStack(alignment: .bottom, spacing: spacing) {
                ForEach(Array(bars.enumerated()), id: \.element.date) { index, bar in
                    let isNewest = index == bars.count - 1
                    let fraction = highest > 0 ? CGFloat(bar.spend / highest) : 0
                    RoundedRectangle(cornerRadius: bars.count > 14 ? 2 : 4, style: .continuous)
                        .fill(isNewest ? WidgetPalette.accent : WidgetPalette.tertiaryInk.opacity(0.35))
                        .frame(height: max(4, fraction * proxy.size.height))
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
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

    @Environment(\.redactionReasons) private var redactionReasons

    var body: some View {
        HStack(spacing: 10) {
            WidgetCategoryIcon(symbolName: row.symbolName, colorToken: row.colorToken)
            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: row.merchant)
                    .font(.subheadline.weight(.medium))
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
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(row.isCredit ? WidgetPalette.income : WidgetPalette.ink)
                .layoutPriority(1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spokenSummary)
    }

    /// Merchant, category, and the movement in words.
    private var spokenSummary: Text {
        let amount = WidgetStrings.spokenAmount(
            row.spokenAmount,
            amountsHidden: amountsHidden,
            redactionReasons: redactionReasons
        )
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
                .background(WidgetPalette.tertiaryInk.opacity(0.18))
                .clipShape(.capsule)
        }
        .frame(height: 8)
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

    @Environment(\.redactionReasons) private var redactionReasons

    var body: some View {
        HStack(spacing: 8) {
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
        let amount = WidgetStrings.spokenAmount(row.amount, amountsHidden: amountsHidden, redactionReasons: redactionReasons)
        return Text(
            "\(row.name), \(amount), \(share) of spending",
            comment: "VoiceOver for a widget category: name, amount or “Hidden”, then its share of this month's spending."
        )
    }
}
