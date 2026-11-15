import SwiftUI

extension View {
    /// The app's filled call-to-action: `.borderedProminent` with a label colour chosen for the
    /// accent fill.
    ///
    /// The system draws a prominent button's label in white. That reads well on the deep teal of
    /// light mode (7.5:1, 11.8:1 with Increase Contrast), but dark mode's accent is a light teal so
    /// that it reads as text on the dark canvas, and white on it falls to 1.9:1 (1.3:1 with Increase
    /// Contrast). `Theme.onAccent` is white in light mode and the dark canvas colour in dark mode,
    /// which keeps the label at 10:1 or more on the fill in every appearance.
    func prominentButtonStyle() -> some View {
        buttonStyle(.borderedProminent)
            .foregroundStyle(Theme.onAccent)
    }
}
