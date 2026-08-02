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
    func cacheEntries() -> [CacheEntry] { entries }
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

    @Test("Excludes com.apple.* and probes already covered elsewhere")
    func excludesSystemAndCovered() async throws {
        let probe = SystemCacheProbe(env: Fixtures.environment())
        let findings = try await probe.scan()
        #expect(findings.count == 1)

        if case let .returnedToOS(b) = findings[0].reclaimable {
            #expect(b == 3_900_000_000 + 3_800_000_000 + 655_000_000)
        } else { Issue.record("reclaimable must be returnedToOS") }
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
