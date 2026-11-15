/// Why the keyword rules screen could not hand a change to the service.
enum CategorizationRulesModelError: Error, Equatable, Sendable {
    /// The chosen category was deleted after the screen last read the store.
    case missingCategory
}
