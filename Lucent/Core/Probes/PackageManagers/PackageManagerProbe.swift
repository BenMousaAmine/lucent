//
//  PackageManagerProbe.swift
//  Lucent
//
//  Created by Amine ben moussa on 31/07/26.
//

import Foundation

struct PackageManagerProbe: DomainProbe {
    let domain: Domain = .packageManager
    private let env: PackageManagerEnvironment
    private let home: URL
    private let searchDepth: Int
    private let manifest: RuleManifest

    init(
        env: PackageManagerEnvironment = RealPackageManagerEnvironment(),
        home: URL = RealPackageManagerEnvironment.home,
        searchDepth: Int = 6,
        manifest: RuleManifest = .default
    ) {
        self.env = env
        self.home = home
        self.searchDepth = searchDepth
        self.manifest = manifest
    }

    func isAvailable() async -> Bool { true }

    func scan() async throws -> [Finding] {
        var findings: [Finding] = []
        if let f = cacheFinding(kind: "npmCache", name: "npm", dir: home.appendingPathComponent(".npm")) {
            findings.append(f)
        }
        if let f = cacheFinding(kind: "pnpmCache", name: "pnpm", dir: home.appendingPathComponent("Library/pnpm/store")) {
            findings.append(f)
        }
        if let f = cacheFinding(kind: "pipCache", name: "pip", dir: home.appendingPathComponent("Library/Caches/pip")) {
            findings.append(f)
        }
        if let f = cacheFinding(kind: "yarnCache", name: "Yarn", dir: home.appendingPathComponent("Library/Caches/Yarn")) {
            findings.append(f)
        }
        if let f = nodeModulesFinding() { findings.append(f) }
        return findings
    }

    // MARK: - Per-category Findings

    private func cacheFinding(kind: String, name: String, dir: URL) -> Finding? {
        guard let total = env.size(of: dir), total > 0 else { return nil }
        let shortPath = dir.path.replacingOccurrences(of: home.path, with: "~")
        let explanation = String(
            localized: "\(name) cache (\(shortPath)). It holds already-downloaded packages to avoid re-downloading them. It's regenerable: removing it frees space on macOS right away, but the next installs will have to download from scratch."
        )
        return makeFinding(kind: kind, nodes: [node(dir, total)],
                           risk: .safe, reversibility: .regenerable,
                           state: .stale, explanation: explanation, comesBack: true)
    }

    private func nodeModulesFinding() -> Finding? {
        let entries = env.findNodeModules(under: home, maxDepth: searchDepth)
        let total = entries.reduce(0) { $0 + $1.physicalSize }
        guard total > 0 else { return nil }
        let projectList = entries
            .sorted { $0.physicalSize > $1.physicalSize }
            .prefix(5)
            .map { "\($0.url.deletingLastPathComponent().lastPathComponent) (\(ByteCountFormatter.string(fromByteCount: $0.physicalSize, countStyle: .file)))" }
            .joined(separator: ", ")
        let explanation = String(
            localized: "\(entries.count) node_modules folders found under home (max depth \(searchDepth)). The largest: \(projectList). They're regenerable with \"npm install\" (or yarn/pnpm), but the first build after deletion needs to re-download all dependencies — make sure you won't need them soon before deleting."
        )
        return makeFinding(kind: "nodeModules", nodes: entries.map { node($0.url, $0.physicalSize) },
                           risk: .conditional, reversibility: .regenerable,
                           state: .stale, explanation: explanation, comesBack: true)
    }

    // MARK: - Helpers

    private func node(_ url: URL, _ size: Int64) -> FileNode {
        FileNode(path: url, logicalSize: size, physicalSize: size, linkCount: 1)
    }

    private func makeFinding(
        kind: String, nodes: [FileNode], risk: RiskTier, reversibility: Reversibility,
        state: FindingState, explanation: String, comesBack: Bool
    ) -> Finding {
        let total = nodes.reduce(0) { $0 + $1.physicalSize }
        let tier = manifest.resolved(domain: .packageManager, kind: kind,
                                     fallbackRisk: risk, fallbackReversibility: reversibility)
        return Finding(
            id: UUID(),
            domain: .packageManager,
            kind: kind,
            nodes: nodes,
            reclaimable: .returnedToOS(total),
            owner: kind == "nodeModules" ? "npm/yarn/pnpm" : "Package manager cache",
            state: state,
            risk: tier.risk,
            reversibility: tier.reversibility,
            explanation: explanation,
            comesBack: comesBack
        )
    }
}
