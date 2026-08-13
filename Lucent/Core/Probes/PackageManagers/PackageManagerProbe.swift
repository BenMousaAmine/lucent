//
//  PackageManagerProbe.swift
//  Lucent
//
//  Created by Amine ben moussa on 31/07/26.
//

import Foundation

struct PackageManagerCache {
    let kind: String
    let name: String
    let relativePath: String
}

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

    private static let caches: [PackageManagerCache] = [
        PackageManagerCache(kind: "npmCache", name: "npm", relativePath: ".npm"),
        PackageManagerCache(kind: "pnpmCache", name: "pnpm", relativePath: "Library/pnpm/store"),
        PackageManagerCache(kind: "pipCache", name: "pip", relativePath: "Library/Caches/pip"),
        PackageManagerCache(kind: "yarnCache", name: "Yarn", relativePath: "Library/Caches/Yarn"),
        PackageManagerCache(kind: "uvCache", name: "uv", relativePath: ".cache/uv"),
        PackageManagerCache(kind: "poetryCache", name: "Poetry", relativePath: "Library/Caches/pypoetry"),
        PackageManagerCache(kind: "cargoCache", name: "Cargo", relativePath: ".cargo/registry"),
        PackageManagerCache(kind: "goCache", name: "Go", relativePath: "go/pkg/mod"),
        PackageManagerCache(kind: "gradleCache", name: "Gradle", relativePath: ".gradle/caches"),
        PackageManagerCache(kind: "mavenCache", name: "Maven", relativePath: ".m2/repository"),
        PackageManagerCache(kind: "composerCache", name: "Composer", relativePath: ".cache/composer"),
        PackageManagerCache(kind: "cocoaPodsCache", name: "CocoaPods", relativePath: "Library/Caches/CocoaPods"),
    ]

    private static let markers: [DependencyMarker] = [
        DependencyMarker(
            kind: "nodeModules", ecosystem: "npm/yarn/pnpm", dirName: "node_modules",
            siblingManifests: ["package.json"], regenerateCommand: "npm install"
        ),
        DependencyMarker(
            kind: "rustTarget", ecosystem: "Cargo", dirName: "target",
            siblingManifests: ["Cargo.toml"], regenerateCommand: "cargo build"
        ),
        DependencyMarker(
            kind: "phpVendor", ecosystem: "Composer", dirName: "vendor",
            siblingManifests: ["composer.json"], regenerateCommand: "composer install"
        ),
        DependencyMarker(
            kind: "cocoaPods", ecosystem: "CocoaPods", dirName: "Pods",
            siblingManifests: ["Podfile"], regenerateCommand: "pod install"
        ),
        DependencyMarker(
            kind: "carthage", ecosystem: "Carthage", dirName: "Carthage",
            siblingManifests: ["Cartfile", "Cartfile.resolved"], regenerateCommand: "carthage bootstrap"
        ),
        DependencyMarker(
            kind: "pythonVenv", ecosystem: "Python", dirName: ".venv",
            siblingManifests: ["pyproject.toml", "requirements.txt", "Pipfile"], regenerateCommand: "pip install"
        ),
        DependencyMarker(
            kind: "pythonVenvEnv", ecosystem: "Python", dirName: "venv",
            siblingManifests: ["pyproject.toml", "requirements.txt", "Pipfile"], regenerateCommand: "pip install"
        ),
    ]

    func isAvailable() async -> Bool { true }

    func scan() async throws -> [Finding] {
        var findings: [Finding] = []
        for cache in Self.caches {
            if let f = cacheFinding(cache) { findings.append(f) }
        }
        for marker in Self.markers {
            if let f = dependencyFinding(marker) { findings.append(f) }
        }
        return findings
    }

    // MARK: - Per-category Findings

    private func cacheFinding(_ cache: PackageManagerCache) -> Finding? {
        let dir = home.appendingPathComponent(cache.relativePath)
        guard let total = env.size(of: dir), total > 0 else { return nil }
        let shortPath = dir.path.replacingOccurrences(of: home.path, with: "~")
        let explanation = String(
            localized: "\(cache.name) cache (\(shortPath)). It holds already-downloaded packages to avoid re-downloading them. It's regenerable: removing it frees space on macOS right away, but the next installs will have to download from scratch."
        )
        return makeFinding(kind: cache.kind, owner: "Package manager cache", nodes: [node(dir, total)],
                           risk: .safe, reversibility: .regenerable,
                           state: .stale, explanation: explanation, comesBack: true)
    }

    private func dependencyFinding(_ marker: DependencyMarker) -> Finding? {
        let entries = env.findDependencyDirs(marker: marker, under: home, maxDepth: searchDepth)
        let total = entries.reduce(0) { $0 + $1.physicalSize }
        guard total > 0 else { return nil }
        let projectList = entries
            .sorted { $0.physicalSize > $1.physicalSize }
            .prefix(5)
            .map { "\($0.url.deletingLastPathComponent().lastPathComponent) (\(ByteCountFormatter.string(fromByteCount: $0.physicalSize, countStyle: .file)))" }
            .joined(separator: ", ")
        let explanation = String(
            localized: "\(entries.count) \(marker.dirName) folders found under home (max depth \(searchDepth)). The largest: \(projectList). They're regenerable with \"\(marker.regenerateCommand)\", but the first build after deletion needs to re-download all dependencies — make sure you won't need them soon before deleting."
        )
        return makeFinding(kind: marker.kind, owner: marker.ecosystem, nodes: entries.map { node($0.url, $0.physicalSize) },
                           risk: .conditional, reversibility: .regenerable,
                           state: .stale, explanation: explanation, comesBack: true)
    }

    // MARK: - Helpers

    private func node(_ url: URL, _ size: Int64) -> FileNode {
        FileNode(path: url, logicalSize: size, physicalSize: size, linkCount: 1)
    }

    private func makeFinding(
        kind: String, owner: String, nodes: [FileNode], risk: RiskTier, reversibility: Reversibility,
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
            owner: owner,
            state: state,
            risk: tier.risk,
            reversibility: tier.reversibility,
            explanation: explanation,
            comesBack: comesBack
        )
    }
}
