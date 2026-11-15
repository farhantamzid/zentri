import UIKit

/// The invisible view that tells the privacy cover which window scene it belongs to.
///
/// SwiftUI updates a representable before its view joins a window, so on the first launch frame the
/// scene is only known once this view moves into a window; it reports that moment.
final class PrivacyCoverAnchorView: UIView {
    var onWindowSceneChange: ((UIWindowScene?) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        isAccessibilityElement = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("PrivacyCoverAnchorView is only created in code.")
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        onWindowSceneChange?(window?.windowScene)
    }
}
