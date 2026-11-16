import SwiftUI

/// How far through setup the person is: one short bar per step, filled up to the current one, which
/// fills as the step changes. VoiceOver reads it as "Step 3 of 7".
struct OnboardingProgressBar: View {
    private let current: Int
    private let total: Int

    init(current: Int, total: Int) {
        self.current = current
        self.total = total
    }

    var body: some View {
        HStack(spacing: 5) {
            ForEach(1...max(total, 1), id: \.self) { step in
                GeometryReader { proxy in
                    Capsule()
                        .fill(Theme.track)
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(Theme.accent)
                                .frame(width: proxy.size.width * fill(for: step))
                        }
                }
                .frame(height: 4)
            }
        }
        .animation(Theme.Motion.settle, value: current)
        .padding(.horizontal, 20)
        .padding(.top, Theme.Spacing.sm)
        .padding(.bottom, Theme.Spacing.md)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Step \(current) of \(total)"))
    }

    /// Steps before the current one are full and the current one is half full.
    private func fill(for step: Int) -> CGFloat {
        if step < current { return 1 }
        if step == current { return 0.5 }
        return 0
    }
}

#Preview {
    OnboardingProgressBar(current: 3, total: 7)
        .ambientBackground()
}
