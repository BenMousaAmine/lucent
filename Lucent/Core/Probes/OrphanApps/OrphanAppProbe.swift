//
//  OrphanAppProbe.swift
//  Lucent
//
//  Created by Amine ben moussa on 31/07/26.
//

import Foundation

struct OrphanAppProbe: DomainProbe {
    let domain: Domain = .orphanApp
    private let env: OrphanAppEnvironment

    private static let minimumReportableSize: Int64 = 1_000_000

    private let manifest: RuleManifest

    init(env: OrphanAppEnvironment = RealOrphanAppEnvironment(),
         manifest: RuleManifest = .default) {
        self.env = env
        self.manifest = manifest
    }

    func isAvailable() async -> Bool { true }

    func scan() async throws -> [Finding] {
        let installed = env.installedBundleIDs()
        let orphans = env.containers()
            .filter { !installed.contains($0.bundleID) && $0.physicalSize >= Self.minimumReportableSize }
            .sorted { $0.physicalSize > $1.physicalSize }

        return orphans.map { orphan in
            let node = FileNode(path: RealOrphanAppEnvironment.home
                .appendingPathComponent("Library/Containers/\(orphan.bundleID)"),
                logicalSize: orphan.physicalSize, physicalSize: orphan.physicalSize, linkCount: 1)
            let lastModifiedText = orphan.lastModified.map {
                DateFormatter.localizedString(from: $0, dateStyle: .medium, timeStyle: .none)
            } ?? String(localized: "unknown date")
            let explanation = String(
                localized: "No installed app matches the bundle \"\(orphan.bundleID)\". This folder holds the data the app left behind (documents, preferences, state) — last modified: \(lastModifiedText). If the app was only temporarily removed, reinstalling it would pick these data back up; otherwise they are leftover remains."
            )
            let tier = manifest.resolved(domain: .orphanApp, kind: "orphanContainer",
                                         fallbackRisk: .conditional, fallbackReversibility: .permanent)
            return Finding(
                id: UUID(),
                domain: .orphanApp,
                kind: "orphanContainer",
                nodes: [node],
                reclaimable: .returnedToOS(orphan.physicalSize),
                owner: orphan.bundleID,
                state: .orphan,
                risk: tier.risk,
                reversibility: tier.reversibility,
                explanation: explanation,
                comesBack: false
            )
        }
    }
}
