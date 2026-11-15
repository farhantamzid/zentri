import SwiftUI

/// One palette color in the category color picker: a swatch and the color's name.
struct CategoryColorOption: View {
    let token: String

    var body: some View {
        Label {
            Text(CategoryStyleOptions.colorName(for: token))
        } icon: {
            Image(systemName: "circle.fill")
                .foregroundStyle(Theme.categoryColor(for: token))
        }
    }
}
