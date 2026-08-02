//
//  PackageManagerProbeTests.swift
//  Lucent
//
//  Created by Amine ben moussa on 21/07/26.
//

import Testing
import Foundation
@testable import Lucent

private struct FakePackageManagerEnvironment: PackageManagerEnvironment {
    var sizes: [URL: Int64] = [:]
    var nodeModules: [PMDirEntry] = []

    func size(of dir: URL) -> Int64? { sizes[dir] }

    func findNodeModules(under root: URL, maxDepth: Int) -> [PMDirEntry] { nodeModules }
}

private enum Fixtures {
    static let home = URL(fileURLWithPath: "/fake/home")

    static func environment() -> FakePackageManagerEnvironment {
        FakePackageManagerEnvironment(
            sizes: [
                home.appendingPathComponent(".npm"): 2_400_000_000,
                home.appendingPathComponent("Library/pnpm/store"): 2_800_000_000,
                home.appendingPathComponent("Library/Caches/pip"): 507_000_000,
            ],
            nodeModules: [
                PMDirEntry(url: home.appendingPathComponent("Projects/Artemis/node_modules"), physicalSize: 300_000_000),
                PMDirEntry(url: home.appendingPathComponent("Projects/guitar-hub/node_modules"), physicalSize: 150_000_000),
            ]
        )
    }
}

struct PackageManagerProbeTests {

    @Test("Produces cache + nodeModules Findings with returnedToOS reclaimable")
    func findings() async throws {
        let probe = PackageManagerProbe(env: Fixtures.environment(), home: Fixtures.home)
        let findings = try await probe.scan()

        let byKind = Dictionary(uniqueKeysWithValues: findings.map { ($0.kind, $0) })
        #expect(Set(byKind.keys) == ["npmCache", "pnpmCache", "pipCache", "nodeModules"])
        #expect(byKind["yarnCache"] == nil)

        if case let .returnedToOS(b) = byKind["npmCache"]!.reclaimable {
            #expect(b == 2_400_000_000)
        } else { Issue.record("npmCache reclaimable must be returnedToOS") }

        if case let .returnedToOS(b) = byKind["nodeModules"]!.reclaimable {
            #expect(b == 450_000_000)
        } else { Issue.record("nodeModules reclaimable must be returnedToOS") }
    }

    @Test("Tiering: caches safe, nodeModules conditional")
    func tiering() async throws {
        let probe = PackageManagerProbe(env: Fixtures.environment(), home: Fixtures.home)
        let byKind = Dictionary(uniqueKeysWithValues: try await probe.scan().map { ($0.kind, $0) })

        #expect(byKind["npmCache"]?.risk == .safe)
        #expect(byKind["npmCache"]?.reversibility == .regenerable)
        #expect(byKind["nodeModules"]?.risk == .conditional)
        #expect(byKind["nodeModules"]?.reversibility == .regenerable)
    }

    @Test("Omits categories with nothing found")
    func omitsEmpty() async throws {
        let empty = FakePackageManagerEnvironment(sizes: [:], nodeModules: [])
        let probe = PackageManagerProbe(env: empty, home: Fixtures.home)
        let findings = try await probe.scan()
        #expect(findings.isEmpty)
    }

    @Test("Always available (filesystem-based, no daemon)")
    func alwaysAvailable() async throws {
        let probe = PackageManagerProbe(env: Fixtures.environment(), home: Fixtures.home)
        #expect(await probe.isAvailable() == true)
    }
}
