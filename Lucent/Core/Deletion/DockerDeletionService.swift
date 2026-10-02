//
//  DockerDeletionService.swift
//  Lucent
//
//  Created by Amine ben moussa on 18/08/26.
//

import Foundation

/// Removes resources that live inside Docker's VM. Unlike filesystem
/// deletions there is no undo: the CLI has no notion of a trash.
struct DockerDeletionService {

    private let runner: DockerCommandRunner

    init(runner: DockerCommandRunner = DockerCommandLineRunner()) {
        self.runner = runner
    }

    /// Arguments the CLI is invoked with for a resource. Kept separate from
    /// `remove` so the mapping can be asserted without running Docker.
    static func arguments(for resource: DockerResource) -> [String] {
        switch resource {
        case .image(let id):      return ["image", "rm", id]
        case .container(let id):  return ["container", "rm", id]
        case .volume(let name):   return ["volume", "rm", name]
        case .buildCache:         return ["builder", "prune", "--all", "--force"]
        case .reclaimSpace:       return ["run", "--rm", "--privileged", "--pid=host", "docker/desktop-reclaim-space"]
        }
    }

    func remove(_ resource: DockerResource) throws {
        _ = try runner.run(Self.arguments(for: resource))
    }

    func reclaimSpace() async throws {
        try await runner.runLong(Self.arguments(for: .reclaimSpace))
    }
}
