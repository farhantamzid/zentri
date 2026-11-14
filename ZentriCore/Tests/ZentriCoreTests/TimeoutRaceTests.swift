import Foundation
import Testing
@testable import ZentriCore

@Test func timeoutRaceReturnsAFastResult() async throws {
    let value = try await TimeoutRace.run(timeout: .seconds(5)) { 42 }

    #expect(value == 42)
}

@Test func timeoutRaceTimesOutASlowOperation() async {
    await #expect(throws: ModelClientError.timedOut) {
        try await TimeoutRace.run(timeout: .milliseconds(10)) {
            try await Task.sleep(for: .seconds(30))
            return 0
        }
    }
}

@Test func timeoutRacePassesThroughAnOperationFailure() async {
    await #expect(throws: ModelTestFailure.generationFailed) {
        try await TimeoutRace.run(timeout: .seconds(5)) {
            throw ModelTestFailure.generationFailed
        }
    }
}
