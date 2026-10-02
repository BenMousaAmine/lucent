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
    var runtimesData = Data("{}".utf8)
    var runtimeAssets: [SimulatorRuntimeAsset] = []

    func subdirectories(of dir: URL) -> [XcodeDirEntry] {
        subdirs[dir] ?? []
    }

    func simulatorDevices() throws -> Data {
        if simctlFails { throw XcodeProbeError.simctlFailed }
        return simctlData ?? Data("{\"devices\":{}}".utf8)
    }

    func simulatorRuntimes() throws -> Data { runtimesData }

    func simulatorRuntimeAssets() -> [SimulatorRuntimeAsset] { runtimeAssets }
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

        // Only the Shutdown device counts: the Booted one is left untouched,
        // so its bytes must not be promised as reclaimable.
        if case let .returnedToOS(b) = byKind["simulators"]!.reclaimable {
            #expect(b == 18_337_792)
        } else { Issue.record("simulators reclaimable must be returnedToOS") }
    }

    @Test("Simulator nodes point at CoreSimulator data dirs, booted ones excluded")
    func simulatorNodesTargetDataDirs() async throws {
        let findings = try await XcodeProbe(env: Fixtures.environment(), root: Fixtures.root).scan()
        let sims = try #require(findings.first { $0.kind == "simulators" })

        // Device B is Booted and must be left alone; only A is removable.
        #expect(sims.nodes.count == 1)
        let path = sims.nodes[0].path.path
        #expect(path.hasSuffix("Library/Developer/CoreSimulator/Devices/A/data"))
        // Never the Xcode root, which holds .doNotTouch Archives.
        #expect(!sims.nodes.contains { $0.path.lastPathComponent == "Xcode" })
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

    @Test("Runtimes Apple still lists are removable; dropped ones are shown as locked, never as removable")
    func simulatorRuntimes() async throws {
        var env = Fixtures.environment()
        env.runtimesData = Data("""
        {"R1":{"identifier":"R1","build":"24A434","version":"27.0","deletable":true,"sizeBytes":8100000000,
               "runtimeIdentifier":"com.apple.CoreSimulator.SimRuntime.iOS-27-0"},
         "R2":{"identifier":"R2","build":"22N840","version":"2.2","deletable":true,"sizeBytes":8800000000,
               "runtimeIdentifier":"com.apple.CoreSimulator.SimRuntime.xrOS-2-2"}}
        """.utf8)
        let assets = URL(fileURLWithPath: "/System/Library/AssetsV2")
        env.runtimeAssets = [
            SimulatorRuntimeAsset(url: assets.appendingPathComponent("a.asset"), platform: "iOS", build: "24A434",
                                  version: "27.0", physicalSize: 8_000_000_000, isOfferedByApple: true),
            SimulatorRuntimeAsset(url: assets.appendingPathComponent("b.asset"), platform: "visionOS", build: "22N840",
                                  version: "2.2", physicalSize: 8_500_000_000, isOfferedByApple: false),
        ]
        let findings = try await XcodeProbe(env: env, root: Fixtures.root).scan()

        let removable = findings.filter { $0.kind == "simulatorRuntime" }
        #expect(removable.count == 1)
        #expect(removable.first?.owner == "iOS 27.0 (24A434)")
        #expect(removable.first?.simulatorResource == .runtime(identifier: "R1"))
        #expect(removable.first?.reclaimable.bytes == 8_100_000_000)
        #expect(removable.first?.isActionable == true)

        let locked = findings.filter { $0.kind == "lockedSimulatorRuntime" }
        #expect(locked.count == 1)
        #expect(locked.first?.owner == "visionOS 2.2 (22N840)")
        #expect(locked.first?.risk == .doNotTouch)
        #expect(locked.first?.simulatorResource == nil)
        #expect(locked.first?.nodes.first?.path.lastPathComponent == "b.asset")
    }

    @Test("Simulators without a system are one removable item and leave the data-dir finding")
    func unavailableSimulators() async throws {
        var env = Fixtures.environment()
        env.simctlData = Data("""
        {"devices":{"com.apple.CoreSimulator.SimRuntime.iOS-18-4":[
            {"udid":"A","name":"iPhone 16","state":"Shutdown","dataPathSize":1000,"isAvailable":false},
            {"udid":"B","name":"iPhone 16 Pro","state":"Shutdown","dataPathSize":2000,"isAvailable":false}
        ],"com.apple.CoreSimulator.SimRuntime.iOS-27-0":[
            {"udid":"C","name":"iPhone 18 Pro Max","state":"Shutdown","dataPathSize":500,"isAvailable":true}
        ]}}
        """.utf8)
        let findings = try await XcodeProbe(env: env, root: Fixtures.root).scan()

        let unavailable = try #require(findings.first { $0.kind == "unavailableSimulators" })
        #expect(unavailable.simulatorResource == .unavailableDevices)
        #expect(unavailable.reclaimable.bytes == 3000)
        #expect(unavailable.risk == .safe)

        let sims = try #require(findings.first { $0.kind == "simulators" })
        #expect(sims.nodes.count == 1)
        #expect(sims.nodes[0].path.path.hasSuffix("Devices/C/data"))
    }

    @Test("Device Support covers every platform, not only iOS")
    func deviceSupportAllPlatforms() async throws {
        var env = Fixtures.environment()
        let watch = Fixtures.root.appendingPathComponent("watchOS DeviceSupport")
        env.subdirs[watch] = [Fixtures.entry("Watch7,11 26.3 (23S620)", size: 5_300_000_000, under: watch)]
        let findings = try await XcodeProbe(env: env, root: Fixtures.root).scan()

        let support = try #require(findings.first { $0.kind == "deviceSupport" })
        #expect(support.nodes.count == 2)
        #expect(support.reclaimable.bytes == 11_000_000_000)
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
