//
//  XcodeProbeTests.swift
//  Lucent
//
//  Created by Amine ben moussa on 21/07/26.
//

import Testing
import Foundation
@testable import Lucent

private struct FakeXcodeEnvironment: XcodeEnvironment {
    var subdirs: [URL: [XcodeDirEntry]] = [:]
    var simctlData: Data?
    var simctlFails = false

    func subdirectories(of dir: URL) -> [XcodeDirEntry] {
        subdirs[dir] ?? []
    }

    func simulatorDevices() throws -> Data {
        if simctlFails { throw XcodeProbeError.simctlFailed }
        return simctlData ?? Data("{\"devices\":{}}".utf8)
    }
}

private enum Fixtures {
    static let root = URL(fileURLWithPath: "/fake/Library/Developer/Xcode")

    static func entry(_ name: String, size: Int64, under dir: URL) -> XcodeDirEntry {
        XcodeDirEntry(url: dir.appendingPathComponent(name), physicalSize: size, lastModified: nil)
    }

    static let simctlJSON = Data("""
    {"devices":{"com.apple.CoreSimulator.SimRuntime.iOS-26-4":[
        {"udid":"A","name":"iPhone 17 Pro","state":"Shutdown","dataPathSize":18337792,"isAvailable":true},
        {"udid":"B","name":"iPhone 17 Pro Max","state":"Booted","dataPathSize":3132493824,"isAvailable":true}
    ]}}
    """.utf8)

    static func environment() -> FakeXcodeEnvironment {
        let derivedData = root.appendingPathComponent("DerivedData")
        let archivesRoot = root.appendingPathComponent("Archives")
        let dateDir = archivesRoot.appendingPathComponent("2026-04-15")
        let deviceSupport = root.appendingPathComponent("iOS DeviceSupport")

        return FakeXcodeEnvironment(subdirs: [
            derivedData: [entry("Lucent-abc", size: 200_000_000, under: derivedData)],
            archivesRoot: [entry("2026-04-15", size: 0, under: archivesRoot)],
            dateDir: [entry("App 15-04-2026.xcarchive", size: 492_000_000, under: dateDir)],
            deviceSupport: [entry("iPhone17,1 26.5 (23F77)", size: 5_700_000_000, under: deviceSupport)],
        ], simctlData: simctlJSON)
    }
}

struct XcodeProbeTests {

    @Test("Produces the four category Findings with returnedToOS reclaimable")
    func fourFindings() async throws {
        let probe = XcodeProbe(env: Fixtures.environment(), root: Fixtures.root)
        let findings = try await probe.scan()

        let byKind = Dictionary(uniqueKeysWithValues: findings.map { ($0.kind, $0) })
        #expect(Set(byKind.keys) == ["derivedData", "archives", "deviceSupport", "simulators"])

        if case let .returnedToOS(b) = byKind["derivedData"]!.reclaimable {
            #expect(b == 200_000_000)
        } else { Issue.record("derivedData reclaimable must be returnedToOS") }

        if case let .returnedToOS(b) = byKind["simulators"]!.reclaimable {
            #expect(b == 18_337_792 + 3_132_493_824)
        } else { Issue.record("simulators reclaimable must be returnedToOS") }
    }

    @Test("Tiering: derivedData safe, archives doNotTouch, deviceSupport/simulators conditional")
    func tiering() async throws {
        let probe = XcodeProbe(env: Fixtures.environment(), root: Fixtures.root)
        let byKind = Dictionary(uniqueKeysWithValues: try await probe.scan().map { ($0.kind, $0) })

        #expect(byKind["derivedData"]?.risk == .safe)
        #expect(byKind["derivedData"]?.reversibility == .regenerable)
        #expect(byKind["archives"]?.risk == .doNotTouch)
        #expect(byKind["archives"]?.reversibility == .permanent)
        #expect(byKind["deviceSupport"]?.risk == .conditional)
        #expect(byKind["simulators"]?.risk == .conditional)
    }

    @Test("Omits categories with nothing found")
    func omitsEmpty() async throws {
        let empty = FakeXcodeEnvironment(subdirs: [:], simctlData: Data("{\"devices\":{}}".utf8))
        let probe = XcodeProbe(env: empty, root: Fixtures.root)
        let findings = try await probe.scan()
        #expect(findings.isEmpty)
    }

    @Test("Degrades gracefully when simctl is unavailable (other findings still returned)")
    func degradesSimctl() async throws {
        var env = Fixtures.environment()
        env.simctlFails = true
        let probe = XcodeProbe(env: env, root: Fixtures.root)
        let findings = try await probe.scan()
        let kinds = Set(findings.map(\.kind))
        #expect(!kinds.contains("simulators"))
        #expect(kinds.contains("derivedData"))
    }
}
