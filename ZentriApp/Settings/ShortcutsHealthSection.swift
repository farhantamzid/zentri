import SwiftUI

/// The guide's ingestion health: the Overview card once the archive is read, and a retry when the
/// read failed, which is never shown as "no failures".
struct ShortcutsHealthSection: View {
    let model: ShortcutsSetupModel

    var body: some View {
        switch model.loadState {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: Theme.Layout.minimumTapTarget)
        case .loaded:
            if let health = model.health {
                IngestionHealthCard(health: health)
            }
        case .failed:
            SectionCard("Ingestion health") {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text("Zentri couldn't read your data just now. Try again.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryInk)
                    Button("Try Again", action: model.refresh)
                        .buttonStyle(.bordered)
                        .frame(minHeight: Theme.Layout.minimumTapTarget)
                        .accessibilityIdentifier("shortcuts.health.retry")
                }
            }
        }
    }
}

#Preview {
    let model = ShortcutsSetupModel(fetchMessages: { [] })
    model.refresh()
    return NavigationStack {
        ShortcutsHealthSection(model: model)
            .padding()
    }
}
