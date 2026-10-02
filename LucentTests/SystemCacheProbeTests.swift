//
//  SystemCacheProbeTests.swift
//  Lucent
//
//  Created by Amine ben moussa on 21/07/26.
//

import Testing
import Foundation
@testable import Lucent

private struct FakeSystemCacheEnvironment: SystemCacheEnvironment {
    var entries: [CacheEntry] = []
    var running: [RunningApp] = []
    func cacheEntries() -> [CacheEntry] { entries }
    func runningApps() -> [RunningApp] { running }
}

private enum Fixtures {
    static func environment() -> FakeSystemCacheEnvironment {
        FakeSystemCacheEnvironment(entries: [
            CacheEntry(name: "JetBrains", physicalSize: 3_900_000_000),
            CacheEntry(name: "Google", physicalSize: 3_800_000_000),
            CacheEntry(name: "Homebrew", physicalSize: 655_000_000),
            CacheEntry(name: "com.apple.textunderstandingd", physicalSize: 301_000_000),
            CacheEntry(name: "pip", physicalSize: 507_000_000),
            CacheEntry(name: "Yarn", physicalSize: 10_000_000),
            CacheEntry(name: "Docker Desktop", physicalSize: 50_000_000),
            CacheEntry(name: "EmptyOne", physicalSize: 0),
        ])
    }
}

struct SystemCacheProbeTests {

    @Test("Caches of apps that are open are left out of the removal and named in the explanation")
    func skipsCachesOfRunningApps() async throws {
        var env = Fixtures.environment()
        env.running = [RunningApp(bundleIdentifier: "com.jetbrains.WebStorm", name: "WebStorm")]
        let finding = try #require(try await SystemCacheProbe(env: env).scan().first)

        #expect(!finding.nodes.contains { $0.path.lastPathComponent == "JetBrains" })
        #expect(finding.nodes.contains { $0.path.lastPathComponent == "Google" })
        #expect(finding.reclaimable.bytes == 3_800_000_000 + 655_000_000)
        #expect(finding.explanation.contains("JetBrains"))
    }

    @Test("A cache folder is matched to a running app by bundle id, vendor or name")
    func inUseMatching() {
        let apps = [RunningApp(bundleIdentifier: "com.google.Chrome", name: "Google Chrome"),
                    RunningApp(bundleIdentifier: "com.anthropic.claudefordesktop", name: "Claude"),
                    RunningApp(bundleIdentifier: "notion.id", name: "Notion")]
        #expect(SystemCacheProbe.isInUse("Google", by: apps))
        #expect(SystemCacheProbe.isInUse("com.anthropic.claudefordesktop.ShipIt", by: apps))
        #expect(SystemCacheProbe.isInUse("notion.id.ShipIt", by: apps))
        #expect(!SystemCacheProbe.isInUse("Homebrew", by: apps))
        #expect(!SystemCacheProbe.isInUse("com.figma.agent", by: apps))
    }

    @Test("Excludes com.apple.* and probes already covered elsewhere")
    func excludesSystemAndCovered() async throws {
        let probe = SystemCacheProbe(env: Fixtures.environment())
        let findings = try await probe.scan()
        #expect(findings.count == 1)

        if case let .returnedToOS(b) = findings[0].reclaimable {
            #expect(b == 3_900_000_000 + 3_800_000_000 + 655_000_000)
        } else { Issue.record("reclaimable must be returnedToOS") }
    }

    @Test("Nodes name each filtered cache, never the parent Caches dir")
    func nodesTargetIndividualCaches() async throws {
        let findings = try await SystemCacheProbe(env: Fixtures.environment()).scan()
        let finding = try #require(findings.first)

        let names = Set(finding.nodes.map { $0.path.lastPathComponent })
        #expect(names == ["JetBrains", "Google", "Homebrew"])

        // The excluded ones must stay unreachable through any node.
        #expect(!names.contains("com.apple.textunderstandingd"))
        #expect(!names.contains("pip"))
        #expect(finding.nodes.allSatisfy { $0.path.lastPathComponent != "Caches" })
    }

    @Test("Always safe and regenerable")
    func tiering() async throws {
        let probe = SystemCacheProbe(env: Fixtures.environment())
        let findings = try await probe.scan()
        #expect(findings[0].risk == .safe)
        #expect(findings[0].reversibility == .regenerable)
    }

    @Test("No Finding when nothing remains after exclusions")
    func nothingLeft() async throws {
        let env = FakeSystemCacheEnvironment(entries: [
            CacheEntry(name: "com.apple.helpd", physicalSize: 30_000_000),
            CacheEntry(name: "pip", physicalSize: 500_000_000),
        ])
        let probe = SystemCacheProbe(env: env)
        let findings = try await probe.scan()
        #expect(findings.isEmpty)
    }
}
