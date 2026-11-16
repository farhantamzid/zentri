import SwiftUI

/// The hero's thirty-day balance line, drawn on with a sweep and scrubbed by dragging.
///
/// While a finger is down the line shows a dashed marker and a dot on the touched day, and the hero
/// shows that day's balance; lifting the finger returns to today. The line is a single `Shape`, so a
/// scrub only moves the marker and never rebuilds the path. VoiceOver can step through the days
/// with the adjustable action instead of dragging.
struct BalanceSparkline: View {
    let points: [BalancePoint]
    @Binding var scrubIndex: Int?

    @Environment(\.moneyFormat) private var moneyFormat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drawn: CGFloat = 0

    private let height: CGFloat = 64

    private var values: [Double] {
        points.map { NSDecimalNumber(decimal: $0.balance).doubleValue }
    }

    var body: some View {
        let values = values
        GeometryReader { proxy in
            let size = proxy.size
            let line = SparklineShape(values: values)
            ZStack(alignment: .topLeading) {
                SparklineShape(values: values, closed: true)
                    .fill(
                        LinearGradient(
                            colors: [Theme.accent.opacity(0.22), Theme.accent.opacity(0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .opacity(Double(drawn))
                line
                    .trim(from: 0, to: drawn)
                    .stroke(Theme.accent, style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))

                if let index = scrubIndex, values.indices.contains(index) {
                    let point = SparklineShape.point(at: index, values: values, in: size)
                    Path { path in
                        path.move(to: CGPoint(x: point.x, y: 0))
                        path.addLine(to: CGPoint(x: point.x, y: size.height))
                    }
                    .stroke(Theme.accent.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    Circle()
                        .fill(Theme.canvas)
                        .stroke(Theme.accent, lineWidth: 2.2)
                        .frame(width: 10, height: 10)
                        .position(point)
                }
            }
            .contentShape(.rect)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let fraction = max(0, min(1, value.location.x / max(size.width, 1)))
                        let index = Int((fraction * CGFloat(values.count - 1)).rounded())
                        if index != scrubIndex {
                            scrubIndex = index
                        }
                    }
                    .onEnded { _ in
                        scrubIndex = nil
                    }
            )
        }
        .frame(height: height)
        .padding(.horizontal, -4)
        .sensoryFeedback(.selection, trigger: scrubIndex.map { $0 / 3 })
        .onAppear {
            guard drawn == 0 else { return }
            if reduceMotion {
                drawn = 1
            } else {
                withAnimation(.timingCurve(0.16, 1, 0.3, 1, duration: 1.4)) {
                    drawn = 1
                }
            }
        }
        .accessibilityElement()
        .accessibilityLabel(Text("Balance, last 30 days"))
        .accessibilityValue(Text(accessibilityValue))
        .accessibilityAdjustableAction { direction in
            let current = scrubIndex ?? points.count - 1
            switch direction {
            case .increment: scrubIndex = min(points.count - 1, current + 1)
            case .decrement: scrubIndex = max(0, current - 1)
            @unknown default: break
            }
        }
    }

    private var accessibilityValue: String {
        let point = scrubIndex.flatMap { points.indices.contains($0) ? points[$0] : nil } ?? points.last
        guard let point else { return "" }
        let day = point.day.formatted(.dateTime.day().month(.wide))
        return "\(day), \(moneyFormat.currencyString(from: point.balance))"
    }
}

/// The balance line through thirty points, closed along the bottom when filled.
struct SparklineShape: Shape {
    let values: [Double]
    /// Whether the path runs back along the bottom edge, for the area fill.
    var closed = false

    static func point(at index: Int, values: [Double], in size: CGSize) -> CGPoint {
        let low = values.min() ?? 0
        let high = values.max() ?? 0
        let span = high - low
        let x = values.count > 1 ? CGFloat(index) / CGFloat(values.count - 1) * size.width : 0
        // The line keeps 6 points of room at the top and bottom, as the design's path does.
        let normalized = span == 0 ? 0.5 : (values[index] - low) / span
        let y = size.height - 6 - CGFloat(normalized) * (size.height - 12)
        return CGPoint(x: x, y: y)
    }

    func path(in rect: CGRect) -> Path {
        guard values.count > 1 else { return Path() }
        var path = Path()
        for index in values.indices {
            let point = Self.point(at: index, values: values, in: rect.size)
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        if closed {
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        }
        return path
    }
}
