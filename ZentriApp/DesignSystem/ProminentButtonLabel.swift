import SwiftUI

/// Colours a prominent button's label for the fill it sits on.
///
/// The system draws a prominent button's label in white. That reads well on the deep teal of light
/// mode (7.5:1, 11.8:1 with Increase Contrast), but dark mode's accent is a light teal so that it
/// reads as text on the dark canvas, and white on it falls to 1.9:1 (1.3:1 with Increase
/// Contrast). While enabled, the label uses `Theme.onAccent` — white in light mode, the dark canvas
/// colour in dark mode — which keeps it at 10:1 or more on the fill in every appearance.
///
/// A disabled button has the system's disabled fill instead of the accent, so `onAccent` would be
/// white on near-white or near-black on black there. Disabled, the label uses
/// `Theme.onAccentDisabled`: secondary ink in dark mode (8.1:1 on the black disabled fill, where the
/// system's own label measures 1.6:1) and ink in light mode, where the system fades any disabled
/// label to about 16% opacity (1.4:1, the same as its own label). The style is one value in both
/// states, so enabling the button never replaces it, and VoiceOver keeps its focus.
struct ProminentButtonLabel: ViewModifier {
    @Environment(\.isEnabled) private var isEnabled

    func body(content: Content) -> some View {
        content.foregroundStyle(labelStyle)
    }

    private var labelStyle: Color {
        isEnabled ? Theme.onAccent : Theme.onAccentDisabled
    }
}
