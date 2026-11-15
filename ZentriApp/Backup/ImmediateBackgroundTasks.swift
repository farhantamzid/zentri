/// Runs background work without asking the system for time, for tests and `-UITestMode`.
@MainActor
struct ImmediateBackgroundTasks: BackgroundTaskRunning {
    func run(named name: String, _ work: @escaping @MainActor () async -> Void) {
        Task {
            await work()
        }
    }
}
