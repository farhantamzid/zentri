/// The screens of the first-run flow, in the order they appear.
///
/// The declaration order is the flow order: the flow moves forward and back through the steps it
/// visits. `rules` is only part of that path when the Rules engine is chosen; every other step
/// always runs.
enum OnboardingStep: Sendable, CaseIterable {
    /// Welcome and the privacy statement.
    case welcome
    /// Currency and number grouping.
    case currency
    /// The first account and its opening balance.
    case account
    /// The parser engine, with the on-device model's availability.
    case parser
    /// Where rules are set up, shown only when Rules is chosen.
    case rules
    /// How messages arrive through Shortcuts.
    case shortcuts
    /// The optional Face ID lock.
    case faceID
}
