import SwiftUI

/// The chart reveal: a short fade and rise the first time a chart appears.
///
/// With Reduce Motion on, the chart is simply there, as spec §13.4 asks.
struct ChartReveal: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed = false

    func body(content: Content) -> some View {
        content
            .opacity(revealed ? 1 : 0)
            .offset(y: revealed ? 0 : Theme.Spacing.sm)
            .onAppear(perform: reveal)
    }

    private func reveal() {
        guard !revealed else { return }
        if reduceMotion {
            revealed = true
        } else {
            withAnimation(.easeOut(duration: 0.45)) {
                revealed = true
            }
        }
    }
}

extension View {
    /// Fades and lifts the chart in on its first appearance, unless Reduce Motion is on.
    func chartReveal() -> some View {
        modifier(ChartReveal())
    }
}
