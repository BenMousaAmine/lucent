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
    var dependencyDirs: [String: [PMDirEntry]] = [:]

    func size(of dir: URL) -> Int64? { sizes[dir] }

    func findDependencyDirs(marker: DependencyMarker, under root: URL, maxDepth: Int) -> [PMDirEntry] {
        dependencyDirs[marker.kind] ?? []
    }
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
            dependencyDirs: [
                "nodeModules": [
                    PMDirEntry(url: home.appendingPathComponent("Projects/Artemis/node_modules"),
                               physicalSize: 300_000_000, lastModified: now.addingTimeInterval(-200 * day)),
                    PMDirEntry(url: home.appendingPathComponent("Projects/guitar-hub/node_modules"),
                               physicalSize: 150_000_000, lastModified: now.addingTimeInterval(-3 * day)),
                ],
            ]
        )
    }

    static let now = Date(timeIntervalSince1970: 1_800_000_000)
    static let day: TimeInterval = 24 * 60 * 60

    static func probe(_ env: FakePackageManagerEnvironment = environment()) -> PackageManagerProbe {
        PackageManagerProbe(env: env, home: home, now: { now })
    }
}

struct PackageManagerProbeTests {

    @Test("Produces cache + nodeModules Findings with returnedToOS reclaimable")
    func findings() async throws {
        let findings = try await Fixtures.probe().scan()

        #expect(Set(findings.map(\.kind)) == ["npmCache", "pnpmCache", "pipCache", "nodeModules"])

        let npm = findings.first { $0.kind == "npmCache" }!
        if case let .returnedToOS(b) = npm.reclaimable {
            #expect(b == 2_400_000_000)
        } else { Issue.record("npmCache reclaimable must be returnedToOS") }
    }

    @Test("One Finding per project, largest first, each carrying its own bytes")
    func splitsPerProject() async throws {
        let nodeModules = try await Fixtures.probe().scan().filter { $0.kind == "nodeModules" }

        #expect(nodeModules.count == 2)
        #expect(nodeModules.map(\.owner) == ["Artemis", "guitar-hub"])
        #expect(nodeModules.map(\.physicalTotal) == [300_000_000, 150_000_000])
        #expect(nodeModules.allSatisfy { $0.nodes.count == 1 })
    }

    @Test("State follows mtime: older than 90 days is stale, recent is live")
    func staleness() async throws {
        let byOwner = Dictionary(
            uniqueKeysWithValues: try await Fixtures.probe()
                .scan()
                .filter { $0.kind == "nodeModules" }
                .map { ($0.owner!, $0) }
        )

        #expect(byOwner["Artemis"]?.state == .stale)
        #expect(byOwner["guitar-hub"]?.state == .live)
    }

    @Test("Unknown mtime is treated as stale")
    func unknownMtimeIsStale() async throws {
        let env = FakePackageManagerEnvironment(
            sizes: [:],
            dependencyDirs: [
                "nodeModules": [
                    PMDirEntry(url: Fixtures.home.appendingPathComponent("Projects/ghost/node_modules"),
                               physicalSize: 1_000_000),
                ],
            ]
        )
        let findings = try await Fixtures.probe(env).scan()
        #expect(findings.count == 1)
        #expect(findings[0].state == .stale)
    }

    @Test("Tiering: caches safe, nodeModules conditional")
    func tiering() async throws {
        let findings = try await Fixtures.probe().scan()
        let npm = findings.first { $0.kind == "npmCache" }
        let nodeModules = findings.filter { $0.kind == "nodeModules" }

        #expect(npm?.risk == .safe)
        #expect(npm?.reversibility == .regenerable)
        #expect(nodeModules.allSatisfy { $0.risk == .conditional })
        #expect(nodeModules.allSatisfy { $0.reversibility == .regenerable })
    }

    @Test("Omits categories with nothing found")
    func omitsEmpty() async throws {
        let empty = FakePackageManagerEnvironment(sizes: [:], dependencyDirs: [:])
        let findings = try await Fixtures.probe(empty).scan()
        #expect(findings.isEmpty)
    }

    @Test("Always available (filesystem-based, no daemon)")
    func alwaysAvailable() async throws {
        #expect(await Fixtures.probe().isAvailable() == true)
    }
}
