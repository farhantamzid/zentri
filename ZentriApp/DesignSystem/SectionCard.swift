import SwiftUI

/// A standard data card: an optional heading over content on the design's glass surface.
///
/// The card's heading is localized and its content is supplied by the feature that owns the data.
struct SectionCard<Content: View>: View {
    private let title: LocalizedStringResource?
    @ContentBuilder let content: Content

    init(_ title: LocalizedStringResource? = nil, @ContentBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            if let title {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                    .accessibilityAddTraits(.isHeader)
            }
            content
        }
        .glassCard()
    }
}

#Preview {
    SectionCard("This month") {
        Text(verbatim: "Spent and received")
            .foregroundStyle(Theme.secondaryInk)
    }
    .padding()
    .ambientBackground()
}
