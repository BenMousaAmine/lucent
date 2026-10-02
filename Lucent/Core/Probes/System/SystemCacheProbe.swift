//
//  SystemCacheProbe.swift
//  Lucent
//
//  Created by Amine ben moussa on 31/07/26.
//

import Foundation

struct SystemCacheProbe: DomainProbe {
    let domain: Domain = .system
    private let env: SystemCacheEnvironment

    private static let coveredByOtherProbes: Set<String> = [
        "pip", "Yarn", "pnpm", "Docker Desktop",
    ]

    private let manifest: RuleManifest

    init(env: SystemCacheEnvironment = RealSystemCacheEnvironment(),
         manifest: RuleManifest = .default) {
        self.env = env
        self.manifest = manifest
    }

    func isAvailable() async -> Bool { true }

    static func isInUse(_ cacheName: String, by apps: [RunningApp]) -> Bool {
        let name = cacheName.lowercased()
        return apps.contains { app in
            let id = app.bundleIdentifier.lowercased()
            return id == name || name.hasPrefix(id + ".") || id.hasPrefix(name + ".")
                || id.split(separator: ".").contains(Substring(name)) || app.name.lowercased() == name
        }
    }

    func scan() async throws -> [Finding] {
        let candidates = env.cacheEntries().filter { entry in
            !entry.name.hasPrefix("com.apple.") &&
            !Self.coveredByOtherProbes.contains(entry.name) &&
            entry.physicalSize > 0
        }
        let running = env.runningApps()
        let busy = candidates.filter { Self.isInUse($0.name, by: running) }
        let entries = candidates.filter { !Self.isInUse($0.name, by: running) }
        let total = entries.reduce(0) { $0 + $1.physicalSize }
        guard total > 0 else { return [] }

        let topList = entries
            .sorted { $0.physicalSize > $1.physicalSize }
            .prefix(5)
            .map { "\($0.name) (\(ByteCountFormatter.string(fromByteCount: $0.physicalSize, countStyle: .file)))" }
            .joined(separator: ", ")
        let explanation = String(
            localized: "\(entries.count) third-party app cache folders in ~/Library/Caches. The largest: \(topList). They're regenerable: apps recreate them when needed, but you may notice a temporary slowdown (e.g. reindexing, re-downloading assets) the first time after. macOS system caches (com.apple.*) are excluded — managed by the system, riskier to touch manually."
        )
        let busyNote = busy.isEmpty ? "" : String(
            localized: " \(busy.count) caches of apps that are open right now are left out, because an open app rebuilds its cache at once: \(busy.map(\.name).sorted().joined(separator: ", ")). Quit those apps and scan again to include them."
        )
        // One node per filtered cache dir. A single node on ~/Library/Caches
        // would have removed the com.apple.* caches this probe excludes on
        // purpose — and macOS refuses to trash that directory anyway.
        let nodes = entries.map {
            FileNode(path: $0.url, logicalSize: $0.physicalSize,
                     physicalSize: $0.physicalSize, linkCount: 1)
        }
        let tier = manifest.resolved(domain: .system, kind: "thirdPartyCaches",
                                     fallbackRisk: .safe, fallbackReversibility: .regenerable)
        let finding = Finding(
            id: UUID(),
            domain: .system,
            kind: "thirdPartyCaches",
            nodes: nodes,
            reclaimable: .returnedToOS(total),
            owner: String(localized: "Third-party apps"),
            state: .stale,
            risk: tier.risk,
            reversibility: tier.reversibility,
            explanation: explanation + busyNote,
            comesBack: true
        )
        return [finding]
    }
}
