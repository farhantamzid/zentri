/// How far a Settings list's last read of the store got.
///
/// A read that threw is its own case so a store that could not be read is never drawn as an empty
/// list, which would tell the person their accounts or categories are gone.
enum SettingsLoadState: Sendable, Equatable {
    /// No read has finished yet.
    case loading
    /// The store was read; an empty list means there really is nothing to show.
    case loaded
    /// A read the screen needs threw, so it offers another attempt.
    case failed
}
