import SwiftUI

/// The container a Swift Chart will sit in once the dashboard and insights screens are built.
///
/// It supplies only the card surface and heading, so chart content, selection, and the
/// accessibility summary are added by the feature that draws the chart rather than here.
struct ChartCard<Content: View>: View {
    private let title: LocalizedStringResource
    @ContentBuilder private let content: Content

    init(_ title: LocalizedStringResource, @ContentBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        SectionCard(title) {
            content
        }
    }
}
