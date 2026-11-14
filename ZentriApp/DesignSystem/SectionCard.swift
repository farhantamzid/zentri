import SwiftUI

/// A standard data card: an optional heading over content on a material surface.
///
/// Data cards never use glass, so text sits on one material layer instead of glass on glass. The
/// card's heading is localized and its content is supplied by the feature that owns the data.
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
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.lg)
        .background(.regularMaterial, in: .rect(cornerRadius: Theme.Radius.card))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .strokeBorder(.separator)
        }
    }
}

#Preview {
    SectionCard("This month") {
        Text("Spent and received")
            .foregroundStyle(Theme.secondaryInk)
    }
    .padding()
    .background(Theme.canvas)
}
