import SwiftUI

/// A row that pushes one Settings destination: a white symbol on its colored square, the title, and
/// the current value when the destination has one.
struct SettingsLink: View {
    let destination: SettingsDestination
    var value: Text?

    var body: some View {
        NavigationLink(value: destination) {
            HStack(spacing: Theme.Spacing.md) {
                SettingsIcon(symbolName: destination.rowSymbol, color: destination.rowColor)
                Text(destination.title)
                    .foregroundStyle(Theme.ink)
                Spacer(minLength: Theme.Spacing.sm)
                if let value {
                    value
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryInk)
                }
            }
            .frame(minHeight: 36)
        }
        .listRowBackground(Theme.glass)
        .alignmentGuide(.listRowSeparatorLeading) { dimensions in dimensions[.leading] + 42 }
        .accessibilityIdentifier(destination.accessibilityIdentifier)
    }
}
