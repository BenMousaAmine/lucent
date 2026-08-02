//
//  RuleManifestTests.swift
//  Lucent
//
//  Created by Amine ben moussa on 29/07/26.
//

import Testing
import Foundation
@testable import Lucent

struct RuleManifestTests {

    @Test("Default manifest reproduces the Xcode probe's original tiers")
    func defaultXcodeRules() {
        let m = RuleManifest.default
        #expect(m.rule(for: .xcode, kind: "derivedData")
                == TieringRule(risk: .safe, reversibility: .regenerable))
        #expect(m.rule(for: .xcode, kind: "archives")
                == TieringRule(risk: .doNotTouch, reversibility: .permanent))
        #expect(m.rule(for: .xcode, kind: "deviceSupport")
                == TieringRule(risk: .conditional, reversibility: .regenerable))
        #expect(m.rule(for: .xcode, kind: "simulators")
                == TieringRule(risk: .conditional, reversibility: .permanent))
    }

    @Test("Default covers every migrated/known kind across domains")
    func defaultCoversKnownKinds() {
        let m = RuleManifest.default
        #expect(m.rule(for: .docker, kind: "danglingImage") != nil)
        #expect(m.rule(for: .docker, kind: "volume") != nil)
        #expect(m.rule(for: .packageManager, kind: "npmCache") != nil)
        #expect(m.rule(for: .packageManager, kind: "nodeModules") != nil)
        #expect(m.rule(for: .orphanApp, kind: "orphanContainer") != nil)
        #expect(m.rule(for: .system, kind: "thirdPartyCaches") != nil)
    }

    @Test("Unknown kind returns nil, never a made-up verdict")
    func unknownKindNil() {
        #expect(RuleManifest.default.rule(for: .xcode, kind: "nope") == nil)
        #expect(RuleManifest.default.rule(for: .unknown, kind: "derivedData") == nil)
    }

    @Test("Manifest round-trips through JSON")
    func jsonRoundTrip() throws {
        let data = try RuleManifest.default.encoded()
        let decoded = try RuleManifest.load(from: data)
        #expect(decoded == RuleManifest.default)
        #expect(decoded.version == 1)
    }
}

private struct ManifestFakeXcodeEnv: XcodeEnvironment {
    let derivedDataRoot: URL
    func subdirectories(of dir: URL) -> [XcodeDirEntry] {
        guard dir == derivedDataRoot else { return [] }
        return [XcodeDirEntry(url: dir.appendingPathComponent("proj"),
                              physicalSize: 1_000, lastModified: nil)]
    }
    func simulatorDevices() throws -> Data { Data("{\"devices\":{}}".utf8) }
}

struct XcodeProbeManifestTests {

    private let root = URL(fileURLWithPath: "/x")
    private func env() -> ManifestFakeXcodeEnv {
        ManifestFakeXcodeEnv(derivedDataRoot: root.appendingPathComponent("DerivedData"))
    }

    private var overrideManifest: RuleManifest {
        RuleManifest(version: 99, rules: [
            Domain.xcode.rawValue: [
                "derivedData": TieringRule(risk: .doNotTouch, reversibility: .permanent),
            ],
        ])
    }

    @Test("Probe applies the manifest's rule over the call-site fallback")
    func probeUsesManifest() async throws {
        let probe = XcodeProbe(env: env(), root: root, manifest: overrideManifest)
        let findings = try await probe.scan()
        let dd = try #require(findings.first { $0.kind == "derivedData" })
        #expect(dd.risk == .doNotTouch)
        #expect(dd.reversibility == .permanent)
    }

    @Test("Default manifest keeps the original derivedData tier (no regression)")
    func probeDefaultUnchanged() async throws {
        let probe = XcodeProbe(env: env(), root: root)
        let findings = try await probe.scan()
        let dd = try #require(findings.first { $0.kind == "derivedData" })
        #expect(dd.risk == .safe)
        #expect(dd.reversibility == .regenerable)
    }
}
