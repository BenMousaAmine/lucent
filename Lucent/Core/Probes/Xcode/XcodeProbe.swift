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
        let devices = (try? env.simulatorDevices()).map { SimctlJSON.decode($0).allDevices } ?? []
        if let f = simulatorsFinding(devices) { findings.append(f) }
        if let f = unavailableSimulatorsFinding(devices) { findings.append(f) }
        findings.append(contentsOf: runtimeFindings())
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
        let entries = Self.deviceSupportFolders.flatMap { env.subdirectories(of: root.appendingPathComponent($0)) }
        let total = entries.reduce(0) { $0 + $1.physicalSize }
        guard total > 0 else { return nil }
        let explanation = String(
            localized: "Debug symbols for \(entries.count) iOS/device versions connected to Xcode in the past. They're needed to debug on a real device with that OS version. If you reconnect the same device with the same version, Xcode re-downloads them automatically; for now-outdated versions you'll rarely need them again."
        )
        return makeFinding(kind: "deviceSupport", nodes: nodes(from: entries),
                           risk: .conditional, reversibility: .regenerable,
                           state: .stale, explanation: explanation, comesBack: true)
    }

    private func simulatorsFinding(_ allDevices: [SimctlDevice]) -> Finding? {
        let devices = allDevices.filter { ($0.dataPathSize ?? 0) > 0 && $0.isAvailable != false }
        let total = devices.reduce(0) { $0 + ($1.dataPathSize ?? 0) }
        guard total > 0 else { return nil }
        let booted = devices.filter { $0.state == "Booted" }
        // One node per device data dir. Pointing at `root` would have trashed
        // the whole ~/Library/Developer/Xcode tree, Archives included.
        let nodes = devices
            .filter { $0.state != "Booted" }
            .map { device in
                FileNode(path: Self.simulatorDataPath(udid: device.udid),
                         logicalSize: device.dataPathSize ?? 0,
                         physicalSize: device.dataPathSize ?? 0,
                         linkCount: 1)
            }
        guard !nodes.isEmpty else { return nil }
        let bootedNote = booted.isEmpty
            ? String(localized: "None are currently running.")
            : String(localized: "\(booted.count) currently running.")
        let explanation = String(
            localized: "\(nodes.count) simulators with removable data (apps, content, simulated user data). \(bootedNote) Running simulators are left out. Deleting a simulator's data is reversible in that the simulator itself stays available, but you lose the apps and data installed inside it — they'll need reinstalling."
        )
        return makeFinding(kind: "simulators", nodes: nodes,
                           risk: .conditional, reversibility: .permanent,
                           state: booted.isEmpty ? .stale : .live,
                           explanation: explanation, comesBack: false)
    }

    private func unavailableSimulatorsFinding(_ allDevices: [SimctlDevice]) -> Finding? {
        let unavailable = allDevices.filter { $0.isAvailable == false }
        guard !unavailable.isEmpty else { return nil }
        let explanation = String(
            localized: "\(unavailable.count) simulators whose system is no longer installed, so they can't start. Removing them also deletes the apps and data inside them. There is no undo."
        )
        return makeFinding(kind: "unavailableSimulators", nodes: [],
                           risk: .safe, reversibility: .permanent,
                           state: .orphan, explanation: explanation, comesBack: false,
                           bytes: unavailable.reduce(0) { $0 + ($1.dataPathSize ?? 0) },
                           simulatorResource: .unavailableDevices)
    }

    private func runtimeFindings() -> [Finding] {
        let locked = env.simulatorRuntimeAssets().filter { !$0.isOfferedByApple }
        let lockedBuilds = Set(locked.map(\.build))
        let removable = ((try? env.simulatorRuntimes()).map(SimctlJSON.decodeRuntimes) ?? [])
            .filter { $0.deletable != false && !lockedBuilds.contains($0.build) }
        return removable.map(runtimeFinding) + locked.map(lockedRuntimeFinding)
    }

    private func runtimeFinding(_ runtime: SimctlRuntime) -> Finding {
        let explanation = String(
            localized: "\(runtime.displayName): the system the Simulator needs to run \(runtime.platform) \(runtime.version) devices. Xcode removes it with its own command, so there is no undo: if you need it again you download it from Xcode → Settings → Components, and simulators created for this version stop working until then."
        )
        return makeFinding(kind: "simulatorRuntime", nodes: [],
                           risk: .conditional, reversibility: .permanent,
                           state: .unknown, explanation: explanation, comesBack: false,
                           owner: runtime.displayName, bytes: runtime.sizeBytes ?? 0,
                           simulatorResource: .runtime(identifier: runtime.identifier))
    }

    private func lockedRuntimeFinding(_ asset: SimulatorRuntimeAsset) -> Finding {
        let explanation = String(
            localized: "\(asset.displayName): a simulator system Apple no longer lists. macOS keeps its downloaded file in a protected system folder, so nothing can delete it while the Mac is running. Xcode's own delete command only hides it for a while: macOS finds the file again, brings the system back and rebuilds its cache. The only way to remove it is from macOS Recovery, by deleting this folder on the Data volume."
        )
        let node = FileNode(path: asset.url, logicalSize: asset.physicalSize,
                            physicalSize: asset.physicalSize, linkCount: 1)
        return makeFinding(kind: "lockedSimulatorRuntime", nodes: [node],
                           risk: .doNotTouch, reversibility: .permanent,
                           state: .orphan, explanation: explanation, comesBack: true,
                           owner: asset.displayName)
    }

    // MARK: - Helpers

    private static let deviceSupportFolders = [
        "iOS DeviceSupport", "watchOS DeviceSupport", "tvOS DeviceSupport",
        "visionOS DeviceSupport", "xrOS DeviceSupport",
    ]

    /// Simulator data lives under CoreSimulator, not under the Xcode dir.
    static func simulatorDataPath(udid: String) -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Developer/CoreSimulator/Devices/\(udid)/data")
    }

    private func nodes(from entries: [XcodeDirEntry]) -> [FileNode] {
        entries.map { FileNode(path: $0.url, logicalSize: $0.physicalSize, physicalSize: $0.physicalSize, linkCount: 1) }
    }

    private func makeFinding(
        kind: String, nodes: [FileNode], risk: RiskTier, reversibility: Reversibility,
        state: FindingState, explanation: String, comesBack: Bool,
        owner: String = "Xcode", bytes: Int64? = nil, simulatorResource: SimulatorResource? = nil
    ) -> Finding {
        let total = bytes ?? nodes.reduce(0) { $0 + $1.physicalSize }
        let tier = manifest.resolved(domain: .xcode, kind: kind,
                                     fallbackRisk: risk, fallbackReversibility: reversibility)
        return Finding(
            id: UUID(),
            domain: .xcode,
            kind: kind,
            nodes: nodes,
            reclaimable: .returnedToOS(total),
            owner: owner,
            state: state,
            risk: tier.risk,
            reversibility: tier.reversibility,
            explanation: explanation,
            comesBack: comesBack,
            simulatorResource: simulatorResource
        )
    }
}
