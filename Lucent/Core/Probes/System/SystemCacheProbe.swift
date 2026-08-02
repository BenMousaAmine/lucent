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

    func scan() async throws -> [Finding] {
        let entries = env.cacheEntries().filter { entry in
            !entry.name.hasPrefix("com.apple.") &&
            !Self.coveredByOtherProbes.contains(entry.name) &&
            entry.physicalSize > 0
        }
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
        let node = FileNode(
            path: RealSystemCacheEnvironment.home.appendingPathComponent("Library/Caches"),
            logicalSize: total, physicalSize: total, linkCount: 1
        )
        let tier = manifest.resolved(domain: .system, kind: "thirdPartyCaches",
                                     fallbackRisk: .safe, fallbackReversibility: .regenerable)
        let finding = Finding(
            id: UUID(),
            domain: .system,
            kind: "thirdPartyCaches",
            nodes: [node],
            reclaimable: .returnedToOS(total),
            owner: String(localized: "Third-party apps"),
            state: .stale,
            risk: tier.risk,
            reversibility: tier.reversibility,
            explanation: explanation,
            comesBack: true
        )
        return [finding]
    }
}
