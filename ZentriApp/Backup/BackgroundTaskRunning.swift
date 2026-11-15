/// Keeps the app running long enough to finish work it starts as it goes to the background.
@MainActor
protocol BackgroundTaskRunning {
    /// Runs `work`, asking the system for background time until it finishes.
    func run(named name: String, _ work: @escaping @MainActor () async -> Void)
}
