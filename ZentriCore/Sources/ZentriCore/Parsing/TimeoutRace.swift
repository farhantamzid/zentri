import Foundation

/// Runs an asynchronous operation with a cooperative time limit.
///
/// The limit bounds how long a well-behaved operation may take, not how long the caller waits.
/// When the timeout expires, the operation's task is cancelled and this function throws
/// ``ModelClientError/timedOut``, but it only returns once the operation yields to that
/// cancellation: an operation that ignored cancellation could still delay the caller, so this
/// is not a hard deadline.
///
/// Structured concurrency cannot abandon a child task, which is why the guarantee is stated in
/// terms of cooperation rather than wall-clock time.
enum TimeoutRace {
    /// The value `operation` produced, or ``ModelClientError/timedOut`` when `timeout` passes
    /// first.
    ///
    /// The first child to finish wins and the other is cancelled before this function returns,
    /// so a fast answer never waits for the timeout to elapse, and a timeout never leaves the
    /// operation running unattended.
    static func run<T: Sendable>(
        timeout: Duration,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(for: timeout)
                throw ModelClientError.timedOut
            }
            defer { group.cancelAll() }
            guard let first = try await group.next() else {
                throw ModelClientError.timedOut
            }
            return first
        }
    }
}
