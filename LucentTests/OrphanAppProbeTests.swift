//
//  OrphanAppProbeTests.swift
//  Lucent
//
//  Created by Amine ben moussa on 21/07/26.
//

import Testing
import Foundation
@testable import Lucent

private struct FakeOrphanAppEnvironment: OrphanAppEnvironment {
    var installed: Set<String> = []
    var entries: [ContainerEntry] = []

    func installedBundleIDs() -> Set<String> { installed }
    func containers() -> [ContainerEntry] { entries }
}

private enum Fixtures {
    static func environment() -> FakeOrphanAppEnvironment {
        FakeOrphanAppEnvironment(
            installed: ["com.anthropic.claudefordesktop", "com.apple.Safari"],
            entries: [
                ContainerEntry(bundleID: "com.anthropic.claudefordesktop", physicalSize: 50_000_000, lastModified: Date()),
                ContainerEntry(bundleID: "app.markchart.markchart", physicalSize: 1_300_000, lastModified: Date()),
                ContainerEntry(bundleID: "com.oldapp.removed", physicalSize: 200_000_000, lastModified: Date()),
                ContainerEntry(bundleID: "com.emptyapp.gone", physicalSize: 0, lastModified: Date()),
            ]
        )
    }
}

struct OrphanAppProbeTests {

    @Test("Flags only containers with no matching installed app")
    func flagsOrphansOnly() async throws {
        let probe = OrphanAppProbe(env: Fixtures.environment())
        let findings = try await probe.scan()

        let owners = Set(findings.map { $0.owner })
        #expect(owners == ["app.markchart.markchart", "com.oldapp.removed"])
        #expect(!owners.contains("com.anthropic.claudefordesktop"))
        #expect(!owners.contains("com.emptyapp.gone"))
    }

    @Test("Sorted by size descending")
    func sortedDescending() async throws {
        let probe = OrphanAppProbe(env: Fixtures.environment())
        let findings = try await probe.scan()
        #expect(findings.first?.owner == "com.oldapp.removed")
    }

    @Test("Never safe — always conditional, one Finding per orphan")
    func neverSafe() async throws {
        let probe = OrphanAppProbe(env: Fixtures.environment())
        let findings = try await probe.scan()
        #expect(findings.allSatisfy { $0.risk == .conditional })
        #expect(findings.allSatisfy { $0.state == .orphan })
        if case let .returnedToOS(b) = findings.first(where: { $0.owner == "com.oldapp.removed" })!.reclaimable {
            #expect(b == 200_000_000)
        } else { Issue.record("orphan reclaimable must be returnedToOS") }
    }

    @Test("No orphans when everything matches an installed app")
    func noOrphans() async throws {
        let env = FakeOrphanAppEnvironment(
            installed: ["com.a.app"],
            entries: [ContainerEntry(bundleID: "com.a.app", physicalSize: 10_000, lastModified: nil)]
        )
        let probe = OrphanAppProbe(env: env)
        let findings = try await probe.scan()
        #expect(findings.isEmpty)
    }

    @Test("Ignores tiny stub containers below 1MB — noise, not reclaimable space")
    func ignoresTinyStubs() async throws {
        let env = FakeOrphanAppEnvironment(
            installed: [],
            entries: (0..<50).map { i in
                ContainerEntry(bundleID: "com.stub.app\(i)", physicalSize: 4_096, lastModified: nil)
            } + [ContainerEntry(bundleID: "com.real.orphan", physicalSize: 5_000_000, lastModified: nil)]
        )
        let probe = OrphanAppProbe(env: env)
        let findings = try await probe.scan()
        #expect(findings.count == 1)
        #expect(findings.first?.owner == "com.real.orphan")
    }
}
