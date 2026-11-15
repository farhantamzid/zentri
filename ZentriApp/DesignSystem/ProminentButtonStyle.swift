import SwiftUI

extension View {
    /// The app's filled call-to-action: `.borderedProminent` with a label colour chosen for the
    /// accent fill while the button is enabled. See ``ProminentButtonLabel``.
    func prominentButtonStyle() -> some View {
        buttonStyle(.borderedProminent)
            .modifier(ProminentButtonLabel())
    }
}
