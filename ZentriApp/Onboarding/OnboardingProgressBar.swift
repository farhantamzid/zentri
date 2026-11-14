import SwiftUI

/// The step indicator at the top of the flow.
///
/// The bar and its "Step N of M" caption are one VoiceOver element, so the position is announced
/// once, and the caption makes the progress legible without relying on the bar's length.
struct OnboardingProgressBar: View {
    private let current: Int
    private let total: Int

    init(current: Int, total: Int) {
        self.current = current
        self.total = total
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            ProgressView(value: Double(current), total: Double(max(total, 1)))
            Text("Step \(current) of \(total)")
                .font(.footnote)
                .foregroundStyle(Theme.secondaryInk)
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.bar)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    OnboardingProgressBar(current: 3, total: 7)
        .background(Theme.canvas)
}
