import SwiftUI
import ZentriCore

/// One category's amount and share of the month's spend, with a bar that fills to its share.
///
/// The row is one accessibility element, so VoiceOver reads the name, the amount, and the share in
/// the order they appear instead of treating the figure as an unlabelled label.
struct TopCategoryRow: View {
    private let category: CategoryTotal
    private let barFraction: Double
    private let delay: Double
    private let onSelect: (@MainActor () -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var filled = false

    init(category: CategoryTotal, barFraction: Double = 1, delay: Double = 0, onSelect: (@MainActor () -> Void)? = nil) {
        self.category = category
        self.barFraction = barFraction
        self.delay = delay
        self.onSelect = onSelect
    }

    var body: some View {
        Button {
            onSelect?()
        } label: {
            HStack(spacing: Theme.Spacing.md) {
                IconTile(symbolName: category.symbolName, colorToken: category.colorToken, size: 36)
                VStack(spacing: 6) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(category.categoryName)
                            .lineLimit(1)
                        Spacer(minLength: Theme.Spacing.sm)
                        MoneyText(category.amount)
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                    HStack(spacing: Theme.Spacing.sm) {
                        GeometryReader { proxy in
                            Capsule()
                                .fill(Theme.track)
                                .overlay(alignment: .leading) {
                                    Capsule()
                                        .fill(Theme.categoryColor(for: category.colorToken))
                                        .frame(width: proxy.size.width * (filled || reduceMotion ? barFraction : 0))
                                }
                        }
                        .frame(height: 5)
                        Text(shareText)
                            .font(.caption)
                            .foregroundStyle(Theme.secondaryInk)
                            .frame(minWidth: 30, alignment: .trailing)
                    }
                }
            }
            .padding(.vertical, Theme.Spacing.sm)
            .contentShape(.rect)
        }
        .buttonStyle(PressableStyle(scale: 0.98))
        .disabled(onSelect == nil)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: spokenSummary))
        .accessibilityHint(onSelect == nil ? Text("") : Text("Shows this category's transactions"))
        .accessibilityIdentifier("overview.category.row")
        .onAppear {
            guard !filled, !reduceMotion else { return }
            withAnimation(Theme.Motion.settle.delay(delay)) {
                filled = true
            }
        }
    }

    @Environment(\.moneyFormat) private var moneyFormat

    private var spokenSummary: String {
        "\(category.categoryName), \(moneyFormat.currencyString(from: category.amount)), \(shareText)"
    }

    /// The category's share of the month's spend, e.g. `100%` or `33%`.
    ///
    /// The summary reports the share already scaled to 100, so it is divided back down for the
    /// percent format style, which expects a fraction.
    private var shareText: String {
        (category.share / 100).formatted(.percent.precision(.fractionLength(0)))
    }
}
