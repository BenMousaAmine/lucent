//
//  XcodeProbe.swift
//  Lucent
//
//  Created by Amine ben moussa on 31/07/26.
//

import Foundation

struct XcodeProbe: DomainProbe {
    let domain: Domain = .xcode
    private let env: XcodeEnvironment
    private let root: URL
    private let manifest: RuleManifest

    init(env: XcodeEnvironment = RealXcodeEnvironment(),
         root: URL = RealXcodeEnvironment.developerRoot,
         manifest: RuleManifest = .default) {
        self.env = env
        self.root = root
        self.manifest = manifest
    }

    func isAvailable() async -> Bool {
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: root.path, isDirectory: &isDir) && isDir.boolValue
    }

    func scan() async throws -> [Finding] {
        var findings: [Finding] = []
        if let f = derivedDataFinding() { findings.append(f) }
        if let f = archivesFinding() { findings.append(f) }
        if let f = deviceSupportFinding() { findings.append(f) }
        if let f = simulatorsFinding() { findings.append(f) }
        return findings
    }

    // MARK: - Per-category Findings

    private func derivedDataFinding() -> Finding? {
        let entries = env.subdirectories(of: root.appendingPathComponent("DerivedData"))
        let total = entries.reduce(0) { $0 + $1.physicalSize }
        guard total > 0 else { return nil }
        let explanation = String(
            localized: "DerivedData holds the intermediate builds of \(entries.count) projects (indexes, compiled objects, SwiftPM cache). Xcode regenerates it automatically on the next build: the first build after deletion will be slower, then back to normal."
        )
        return makeFinding(kind: "derivedData", nodes: nodes(from: entries),
                           risk: .safe, reversibility: .regenerable,
                           state: .stale, explanation: explanation, comesBack: true)
    }

    private func archivesFinding() -> Finding? {
        let dateDirs = env.subdirectories(of: root.appendingPathComponent("Archives"))
        let archives = dateDirs.flatMap { env.subdirectories(of: $0.url) }
        let total = archives.reduce(0) { $0 + $1.physicalSize }
        guard total > 0 else { return nil }
        let explanation = String(
            localized: "\(archives.count) archives (.xcarchive) from past builds — they contain the signed binary and debug symbols used to analyze crash reports or re-publish to TestFlight/App Store. Once deleted they are NOT regenerable: only a new build can recreate them, but without the same symbols for versions already distributed."
        )
        return makeFinding(kind: "archives", nodes: nodes(from: archives),
                           risk: .doNotTouch, reversibility: .permanent,
                           state: .live, explanation: explanation, comesBack: false)
    }

    private func deviceSupportFinding() -> Finding? {
        let entries = env.subdirectories(of: root.appendingPathComponent("iOS DeviceSupport"))
        let total = entries.reduce(0) { $0 + $1.physicalSize }
        guard total > 0 else { return nil }
        let explanation = String(
            localized: "Debug symbols for \(entries.count) iOS/device versions connected to Xcode in the past. They're needed to debug on a real device with that OS version. If you reconnect the same device with the same version, Xcode re-downloads them automatically; for now-outdated versions you'll rarely need them again."
        )
        return makeFinding(kind: "deviceSupport", nodes: nodes(from: entries),
                           risk: .conditional, reversibility: .regenerable,
                           state: .stale, explanation: explanation, comesBack: true)
    }

    private func simulatorsFinding() -> Finding? {
        guard let data = try? env.simulatorDevices() else { return nil }
        let list = SimctlJSON.decode(data)
        let devices = list.allDevices.filter { ($0.dataPathSize ?? 0) > 0 }
        let total = devices.reduce(0) { $0 + ($1.dataPathSize ?? 0) }
        guard total > 0 else { return nil }
        let booted = devices.filter { $0.state == "Booted" }
        let node = FileNode(path: root, logicalSize: total, physicalSize: total, linkCount: 1)
        let bootedNote = booted.isEmpty
            ? String(localized: "None are currently running.")
            : String(localized: "\(booted.count) currently running.")
        let explanation = String(
            localized: "\(devices.count) simulators with installed data (apps, content, simulated user data). \(bootedNote) Deleting a simulator's data is reversible in that the simulator itself stays available, but you lose the apps and data installed inside it — they'll need reinstalling."
        )
        return makeFinding(kind: "simulators", nodes: [node],
                           risk: .conditional, reversibility: .permanent,
                           state: booted.isEmpty ? .stale : .live,
                           explanation: explanation, comesBack: false)
    }

    // MARK: - Helpers

    private func nodes(from entries: [XcodeDirEntry]) -> [FileNode] {
        entries.map { FileNode(path: $0.url, logicalSize: $0.physicalSize, physicalSize: $0.physicalSize, linkCount: 1) }
    }

    private func makeFinding(
        kind: String, nodes: [FileNode], risk: RiskTier, reversibility: Reversibility,
        state: FindingState, explanation: String, comesBack: Bool
    ) -> Finding {
        let total = nodes.reduce(0) { $0 + $1.physicalSize }
        let tier = manifest.resolved(domain: .xcode, kind: kind,
                                     fallbackRisk: risk, fallbackReversibility: reversibility)
        return Finding(
            id: UUID(),
            domain: .xcode,
            kind: kind,
            nodes: nodes,
            reclaimable: .returnedToOS(total),
            owner: "Xcode",
            state: state,
            risk: tier.risk,
            reversibility: tier.reversibility,
            explanation: explanation,
            comesBack: comesBack
        )
    }
}
