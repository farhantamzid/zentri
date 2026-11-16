import SwiftUI
import ZentriCore

/// The balance hero: the combined balance over a soft, drifting glow, with this month's net, the
/// last thirty days as a line you can scrub, and today's spend.
///
/// Dragging across the line shows the balance at the end of that day, with how much it has changed
/// since. The amount rolls between values with the system's numeric transition, which the render
/// server animates at the display's full refresh rate. The glow drifts only while the hero is on
/// screen, and stays still with Reduce Motion on; with Reduce Transparency on, the card is opaque.
struct BalanceHero: View {
    private let balance: Decimal
    private let asOf: Date
    private let todaySpend: Decimal
    private let monthNet: Decimal
    private let history: [BalancePoint]

    @Environment(\.moneyFormat) private var moneyFormat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @State private var scrubIndex: Int?
    @State private var appeared = false

    init(
        balance: Decimal,
        asOf: Date,
        todaySpend: Decimal,
        monthNet: Decimal = 0,
        history: [BalancePoint] = []
    ) {
        self.balance = balance
        self.asOf = asOf
        self.todaySpend = todaySpend
        self.monthNet = monthNet
        self.history = history
    }

    private var scrubbedPoint: BalancePoint? {
        scrubIndex.flatMap { history.indices.contains($0) ? history[$0] : nil }
    }

    /// The figure the hero shows: the scrubbed day's balance, or the current one. Before the hero
    /// first appears it is zero, so the digits roll up into place.
    private var shownAmount: Decimal {
        guard appeared || reduceMotion else { return 0 }
        return scrubbedPoint?.balance ?? balance
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            amount
                .padding(.top, Theme.Spacing.xs)
            delta
                .padding(.top, 2)
            if history.count > 1 {
                BalanceSparkline(points: history, scrubIndex: $scrubIndex)
                    .padding(.top, 14)
                axisLabels
                    .padding(.top, 6)
            }
            chips
                .padding(.top, Theme.Spacing.md)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 22)
        .padding(.top, 20)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { surface }
        .background { HeroGlow(isScrubbing: scrubIndex != nil) }
        .onAppear {
            guard !appeared else { return }
            withAnimation(Theme.Motion.settle) {
                appeared = true
            }
        }
    }

    // MARK: Parts

    private var header: some View {
        HStack {
            Group {
                if let point = scrubbedPoint {
                    Text("Balance on \(point.day, format: .dateTime.day().month(.abbreviated))")
                } else {
                    Text("Combined balance")
                }
            }
            .font(.subheadline)
            .foregroundStyle(Theme.secondaryInk)
            .contentTransition(.opacity)
            .accessibilityHidden(true)
            Spacer(minLength: Theme.Spacing.sm)
            LiveChip()
                .accessibilityHidden(true)
        }
    }

    private var amount: some View {
        let parts = MoneyParts(moneyFormat.currencyString(from: shownAmount))
        return HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(parts.whole)
                .font(.system(size: 46, weight: .semibold))
                .kerning(-1.1)
            Text(parts.fraction)
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(Theme.tertiaryInk)
        }
        .monospacedDigit()
        .foregroundStyle(Theme.ink)
        .lineLimit(1)
        .minimumScaleFactor(0.5)
        .contentTransition(reduceMotion ? .identity : .numericText(value: NSDecimalNumber(decimal: shownAmount).doubleValue))
        .animation(scrubIndex == nil ? Theme.Motion.settle : .smooth(duration: 0.3), value: shownAmount)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(spokenSummary))
        .accessibilityIdentifier("overview.balance")
    }

    /// The hero as one statement: the balance, today's spend, and when the balance was read.
    private var spokenSummary: String {
        let asOfText = asOf.formatted(.dateTime.month(.abbreviated).day().hour().minute())
        return String(localized: "Combined balance, \(moneyFormat.currencyString(from: balance)). Spent today \(moneyFormat.currencyString(from: todaySpend)). As of \(asOfText)")
    }

    private var delta: some View {
        Group {
            if let point = scrubbedPoint {
                let change = balance - point.balance
                Label {
                    if change == 0 {
                        Text("Today")
                    } else {
                        Text("\(moneyFormat.signedCurrencyString(from: change)) since then")
                    }
                } icon: {
                    Image(systemName: "clock.arrow.circlepath")
                }
                .foregroundStyle(Theme.secondaryInk)
            } else {
                Label {
                    Text("\(moneyFormat.signedCurrencyString(from: monthNet)) this month")
                } icon: {
                    Image(systemName: monthNet < 0 ? "chart.line.downtrend.xyaxis" : "chart.line.uptrend.xyaxis")
                }
                .foregroundStyle(monthNet < 0 ? Theme.spending : Theme.income)
            }
        }
        .font(.subheadline.weight(.medium))
        .labelStyle(TightLabelStyle())
        .monospacedDigit()
        .contentTransition(.opacity)
    }

    private var axisLabels: some View {
        HStack {
            if let first = history.first {
                Text(first.day, format: .dateTime.day().month(.abbreviated))
            }
            Spacer()
            Text("Drag to scrub")
                .fontWeight(.semibold)
                .foregroundStyle(Theme.accent)
                .opacity(scrubIndex == nil ? 1 : 0)
                .animation(.easeOut(duration: 0.3), value: scrubIndex == nil)
                .accessibilityHidden(true)
            Spacer()
            Text("Today")
        }
        .font(.caption)
        .foregroundStyle(Theme.tertiaryInk)
    }

    private var chips: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Theme.Spacing.sm) {
                spentTodayChip
                asOfText
            }
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                spentTodayChip
                asOfText
            }
        }
    }

    private var spentTodayChip: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Text("Spent today")
            MoneyText(todaySpend)
                .fontWeight(.bold)
                .foregroundStyle(Theme.ink)
        }
        .font(.footnote)
        .foregroundStyle(Theme.secondaryInk)
        // One line, so a tight row falls back to the stacked layout instead of wrapping the chip.
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .background(Theme.chip, in: .capsule)
        .overlay { Capsule().strokeBorder(Theme.glassBorder) }
        .accessibilityElement(children: .combine)
    }

    private var asOfText: some View {
        Text("As of \(asOf, format: .dateTime.month(.abbreviated).day().hour().minute())")
            .font(.footnote)
            .foregroundStyle(Theme.tertiaryInk)
    }

    private var surface: some View {
        let shape = RoundedRectangle(cornerRadius: Theme.Radius.hero, style: .continuous)
        return shape
            .fill(reduceTransparency ? AnyShapeStyle(Theme.canvas) : AnyShapeStyle(Theme.heroGlass))
            .background {
                if !reduceTransparency {
                    shape.fill(.ultraThinMaterial)
                }
            }
            .overlay {
                shape.fill(
                    LinearGradient(
                        colors: [Theme.sheen, Theme.sheen.opacity(0)],
                        startPoint: .top,
                        endPoint: UnitPoint(x: 0.5, y: 0.6)
                    )
                )
            }
            .overlay {
                shape.strokeBorder(
                    LinearGradient(colors: [Theme.glassHighlight, Theme.glassBorder], startPoint: .top, endPoint: .bottom),
                    lineWidth: 1
                )
            }
            .shadow(color: Theme.cardShadow, radius: 16, y: 10)
    }
}

// MARK: - Money parts

/// A formatted amount split into its whole part and its decimal part, so the cents can be drawn
/// smaller, e.g. `$12,345` and `.67`.
struct MoneyParts {
    let whole: String
    let fraction: String

    init(_ formatted: String) {
        let characters = Array(formatted)
        // The cents follow the last "." or ",", and are one or two digits. A run of three digits
        // after the last separator is a thousands group, as in a whole-number currency like yen.
        if let index = characters.lastIndex(where: { $0 == "." || $0 == "," }),
           case let tail = characters[(index + 1)...],
           (1...2).contains(tail.count),
           tail.allSatisfy(\.isNumber)
        {
            whole = String(characters[..<index])
            fraction = String(characters[index...])
        } else {
            whole = formatted
            fraction = ""
        }
    }
}

extension MoneyFormat {
    /// The amount rounded to a whole number and shown without its cents, e.g. `$1,250`.
    func wholeCurrencyString(from amount: Decimal) -> String {
        var source = amount
        var rounded = Decimal()
        NSDecimalRound(&rounded, &source, 0, .plain)
        return MoneyParts(currencyString(from: rounded)).whole
    }

    /// The amount with an explicit sign, `+$1.00` or `−$1.00`, for changes rather than balances.
    func signedCurrencyString(from amount: Decimal) -> String {
        let magnitude = currencyString(from: amount < 0 ? -amount : amount)
        // A word joiner keeps the sign on the same line as the amount when the text wraps.
        if amount > 0 { return "+\u{2060}" + magnitude }
        if amount < 0 { return "\u{2212}\u{2060}" + magnitude }
        return magnitude
    }
}

/// An icon and title with a small gap, as the design's inline status lines draw them.
struct TightLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 5) {
            configuration.icon
            configuration.title
        }
    }
}

// MARK: - Glow

/// Three soft lights behind the hero that drift to new colors and places every few seconds, and
/// brighten while the balance line is scrubbed.
private struct HeroGlow: View {
    let isScrubbing: Bool

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var spots = GlowSpot.initial

    private static let palette: [Color] = [
        Color(light: 0x2EC4B6, dark: 0x2EC4B6), Color(light: 0x5FD0C4, dark: 0x5FD0C4),
        Color(light: 0xF0A43A, dark: 0xF0A43A), Color(light: 0xFF7A5C, dark: 0xFF7A5C),
        Color(light: 0x8B7BFF, dark: 0x8B7BFF), Color(light: 0x4FB3E8, dark: 0x4FB3E8),
        Color(light: 0x7ED492, dark: 0x7ED492), Color(light: 0xF27BA8, dark: 0xF27BA8),
    ]

    var body: some View {
        let base = Theme.glowStrength(colorScheme)
        GeometryReader { proxy in
            ZStack {
                ForEach(spots.indices, id: \.self) { index in
                    let spot = spots[index]
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Self.palette[spot.color], Self.palette[spot.color].opacity(0)],
                                center: .center,
                                startRadius: 0,
                                endRadius: spot.size / 2 + 46
                            )
                        )
                        .frame(width: spot.size + 92, height: spot.size + 92)
                        .position(x: proxy.size.width * spot.x, y: proxy.size.height * spot.y)
                }
            }
            .opacity(isScrubbing ? min(1, base * 1.4) : base)
            .scaleEffect(isScrubbing ? 1.22 : 1)
            .animation(.spring(response: 0.6, dampingFraction: 0.7), value: isScrubbing)
        }
        .padding(.vertical, -24)
        .padding(.horizontal, -8)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task {
            guard !reduceMotion else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(4))
                guard !Task.isCancelled else { return }
                withAnimation(.easeInOut(duration: 3.6)) {
                    spots = GlowSpot.random(paletteCount: Self.palette.count)
                }
            }
        }
    }
}

private struct GlowSpot: Equatable {
    var color: Int
    var x: CGFloat
    var y: CGFloat
    var size: CGFloat

    static let initial = [
        GlowSpot(color: 0, x: 0.22, y: 0.30, size: 200),
        GlowSpot(color: 2, x: 0.78, y: 0.65, size: 180),
        GlowSpot(color: 4, x: 0.55, y: 0.15, size: 140),
    ]

    static func random(paletteCount: Int) -> [GlowSpot] {
        let colors = Array((0..<paletteCount).shuffled().prefix(3))
        return zip(colors, [200, 180, 140] as [CGFloat]).map { color, size in
            GlowSpot(color: color, x: .random(in: 0.12...0.88), y: .random(in: 0.10...0.90), size: size)
        }
    }
}

#Preview {
    BalanceHero(balance: 12_345.67, asOf: .now, todaySpend: 82.4, monthNet: 3_750)
        .padding()
        .ambientBackground()
}
