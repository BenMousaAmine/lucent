import Testing
import Foundation
@testable import Lucent

private final class RecordingSimctlRunner: SimctlCommandRunner, @unchecked Sendable {
    private(set) var invocations: [[String]] = []
    var failure: Error?

    func run(_ args: [String]) throws -> Data {
        invocations.append(args)
        if let failure { throw failure }
        return Data()
    }
}

struct SimulatorDeletionServiceTests {

    @Test("Each resource maps to the simctl command that removes it")
    func argumentMapping() {
        #expect(SimulatorDeletionService.arguments(for: .runtime(identifier: "R1")) == ["runtime", "delete", "R1"])
        #expect(SimulatorDeletionService.arguments(for: .unavailableDevices) == ["delete", "unavailable"])
    }

    @Test("Removal invokes simctl exactly once with those arguments")
    func removeInvokesSimctl() throws {
        let runner = RecordingSimctlRunner()
        try SimulatorDeletionService(runner: runner).remove(.runtime(identifier: "R1"))
        #expect(runner.invocations == [["runtime", "delete", "R1"]])
    }

    @Test("A refusing simctl surfaces as a thrown error, never a silent success")
    func failurePropagates() {
        let runner = RecordingSimctlRunner()
        runner.failure = SimctlError.commandFailed(args: ["delete", "unavailable"], stderr: "nope")
        #expect(throws: SimctlError.self) {
            try SimulatorDeletionService(runner: runner).remove(.unavailableDevices)
        }
    }
}
