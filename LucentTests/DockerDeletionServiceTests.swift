//
//  DockerDeletionServiceTests.swift
//  Lucent
//
//  Created by Amine ben moussa on 18/08/26.
//

import Testing
import Foundation
@testable import Lucent

private final class RecordingRunner: DockerCommandRunner, @unchecked Sendable {
    private(set) var invocations: [[String]] = []
    var failure: Error?

    func run(_ args: [String]) throws -> Data {
        invocations.append(args)
        if let failure { throw failure }
        return Data()
    }
}

struct DockerDeletionServiceTests {

    @Test("Each resource maps to the CLI command that actually removes it")
    func argumentMapping() {
        #expect(DockerDeletionService.arguments(for: .image(id: "sha256:abc"))
                == ["image", "rm", "sha256:abc"])
        #expect(DockerDeletionService.arguments(for: .container(id: "c1"))
                == ["container", "rm", "c1"])
        #expect(DockerDeletionService.arguments(for: .volume(name: "pgdata"))
                == ["volume", "rm", "pgdata"])
        #expect(DockerDeletionService.arguments(for: .buildCache)
                == ["builder", "prune", "--all", "--force"])
        #expect(DockerDeletionService.arguments(for: .reclaimSpace)
                == ["run", "--rm", "--privileged", "--pid=host", "docker/desktop-reclaim-space"])
    }

    @Test("Compaction goes through the long-running path with the reclaim command")
    func reclaimSpaceInvokesCLI() async throws {
        let runner = RecordingRunner()
        try await DockerDeletionService(runner: runner).reclaimSpace()
        #expect(runner.invocations == [["run", "--rm", "--privileged", "--pid=host", "docker/desktop-reclaim-space"]])
    }

    @Test("Removal invokes the CLI exactly once with those arguments")
    func removeInvokesCLI() throws {
        let runner = RecordingRunner()
        let service = DockerDeletionService(runner: runner)

        try service.remove(.volume(name: "pgdata"))

        #expect(runner.invocations == [["volume", "rm", "pgdata"]])
    }

    @Test("A refusing daemon surfaces as a thrown error, never a silent success")
    func failurePropagates() {
        let runner = RecordingRunner()
        runner.failure = DockerCLIError.commandFailed(
            args: ["volume", "rm", "pgdata"], status: 1,
            stderr: "volume is in use"
        )
        let service = DockerDeletionService(runner: runner)

        #expect(throws: DockerCLIError.self) {
            try service.remove(.volume(name: "pgdata"))
        }
    }
}
