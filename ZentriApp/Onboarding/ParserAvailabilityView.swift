import SwiftUI
import ZentriCore

/// Whether the on-device model can read messages here.
///
/// The status is informational: Rules always works, and an unavailable model never blocks the
/// step. When the model cannot run, the reason it gives is shown instead of a generic failure.
struct ParserAvailabilityView: View {
    private let availability: ModelAvailability?

    init(availability: ModelAvailability?) {
        self.availability = availability
    }

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            Image(systemName: symbolName)
                .font(.title3)
                .foregroundStyle(tint)
                .frame(minWidth: 24)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("Foundation Models")
                    .font(.subheadline.bold())
                    .foregroundStyle(Theme.ink)

                switch availability {
                case nil:
                    HStack(spacing: Theme.Spacing.sm) {
                        ProgressView()
                        Text("Checking availability…")
                            .font(.footnote)
                            .foregroundStyle(Theme.secondaryInk)
                    }
                case .available:
                    Text("Available on this iPhone.")
                        .font(.footnote)
                        .foregroundStyle(Theme.secondaryInk)
                case .unavailable(let reason):
                    Text(reason)
                        .font(.footnote)
                        .foregroundStyle(Theme.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.md)
        .background(.regularMaterial, in: .rect(cornerRadius: Theme.Radius.card))
        .accessibilityElement(children: .combine)
    }

    private var symbolName: String {
        switch availability {
        case .available: "checkmark.circle"
        default: "info.circle"
        }
    }

    private var tint: Color {
        switch availability {
        case .available: Theme.income
        default: Theme.secondaryInk
        }
    }
}

#Preview {
    VStack(spacing: Theme.Spacing.sm) {
        ParserAvailabilityView(availability: nil)
        ParserAvailabilityView(availability: .available)
        ParserAvailabilityView(availability: .unavailable("Apple Intelligence is turned off in Settings."))
    }
    .padding()
    .background(Theme.canvas)
}
