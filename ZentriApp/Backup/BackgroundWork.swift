/// Runs blocking work — coordinated file I/O, encoding, decoding — off the main actor.
enum BackgroundWork {
    /// Runs `work` on the concurrent executor and returns its result.
    @concurrent
    static func run<Value: Sendable>(_ work: @Sendable () throws -> Value) async throws -> Value {
        try work()
    }
}
