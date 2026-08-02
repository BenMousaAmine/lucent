//
//  DockerProbe.swift
//  Lucent
//
//  Created by Amine ben moussa on 31/07/26.
//

import Foundation

struct DockerProbe: DomainProbe {
    let domain: Domain = .docker
    private let runner: DockerCommandRunner
    private let manifest: RuleManifest

    init(runner: DockerCommandRunner = DockerCommandLineRunner(),
         manifest: RuleManifest = .default) {
        self.runner = runner
        self.manifest = manifest
    }

    private func tier(_ kind: String, _ risk: RiskTier, _ rev: Reversibility)
        -> (risk: RiskTier, reversibility: Reversibility) {
        manifest.resolved(domain: .docker, kind: kind, fallbackRisk: risk, fallbackReversibility: rev)
    }

    func isAvailable() async -> Bool {
        (try? runner.run(["info"])) != nil
    }

    func scan() async throws -> [Finding] {
        let df = try decodeLines(runner.run(["system", "df", "--format", "json"]), as: DockerDfRow.self)
        let images = (try? decodeLines(runner.run(["image", "ls", "--format", "json"]), as: DockerImageRow.self)) ?? []
        let containers = (try? decodeLines(runner.run(["container", "ls", "-a", "--size", "--format", "json"]), as: DockerContainerRow.self)) ?? []
        let volumeNames = (try? decodeLines(runner.run(["volume", "ls", "--format", "json"]), as: DockerVolumeRow.self)) ?? []
        let volumeUsage = (try? DockerVolumeUsage.parse(String(decoding: runner.run(["system", "df", "-v"]), as: UTF8.self))) ?? []

        var findings: [Finding] = []
        findings += imageFindings(images: images)
        if let f = buildCacheFinding(df: df) { findings.append(f) }
        findings += containerFindings(containers: containers)
        findings += volumeFindings(volumeNames: volumeNames, usage: volumeUsage)
        return findings
    }

    // MARK: - Per-element Findings (one per image/container/volume, per user request 2026-07-21:

    private func imageFindings(images: [DockerImageRow]) -> [Finding] {
        images
            .filter { ($0.Containers == "0") || $0.Tag == "<none>" }
            .compactMap { image in
                guard let bytes = DockerByteSize.bytes(from: image.Size), bytes > 0 else { return nil }
                let explanation = String(
                    localized: "Image \"\(image.displayName)\" (ID \(image.ID)), not used by any container. Removing it frees space INSIDE Docker's VM, but it isn't returned to macOS until you compact Docker's disk (Docker.raw doesn't shrink on its own). Regenerable: if you still need it, a new pull or build recreates it."
                )
                let t = tier("danglingImage", .safe, .regenerable)
                return Finding(
                    id: UUID(), domain: .docker, kind: "danglingImage", nodes: [],
                    reclaimable: .freedInContainerOnly(bytes), owner: image.displayName,
                    state: .stale, risk: t.risk, reversibility: t.reversibility,
                    explanation: explanation, comesBack: true
                )
            }
    }

    private func buildCacheFinding(df: [DockerDfRow]) -> Finding? {
        guard let row = df.first(where: { $0.type == "Build Cache" }),
              let reclaim = DockerByteSize.bytes(from: row.Reclaimable), reclaim > 0
        else { return nil }
        let explanation = String(
            localized: "Docker's build cache (\(row.TotalCount) layers) speeds up builds. They are anonymous intermediate layers (internal IDs, not readable names) — you can't pick a specific layer to keep. It's regenerable: removing it frees space in Docker's VM (not returned to macOS until you compact the disk). Later builds will be slower until the cache rebuilds."
        )
        let t = tier("buildCache", .safe, .regenerable)
        return Finding(
            id: UUID(), domain: .docker, kind: "buildCache", nodes: [],
            reclaimable: .freedInContainerOnly(reclaim), owner: "Docker daemon",
            state: .stale, risk: t.risk, reversibility: t.reversibility,
            explanation: explanation, comesBack: true
        )
    }

    private func containerFindings(containers: [DockerContainerRow]) -> [Finding] {
        containers
            .filter { $0.State != "running" }
            .compactMap { container in
                guard let bytes = DockerByteSize.bytes(from: container.Size) else { return nil }
                let explanation = String(
                    localized: "Container \"\(container.Names)\" (image \(container.Image)), stopped — \(container.Status). You might want to restart it: check before removing. The freed space (the container's writable size, not the shared image) stays in Docker's VM."
                )
                let t = tier("stoppedContainer", .conditional, .permanent)
                return Finding(
                    id: UUID(), domain: .docker, kind: "stoppedContainer", nodes: [],
                    reclaimable: .freedInContainerOnly(bytes), owner: container.Names,
                    state: .stale, risk: t.risk, reversibility: t.reversibility,
                    explanation: explanation, comesBack: false
                )
            }
    }

    private func volumeFindings(volumeNames: [DockerVolumeRow], usage: [DockerVolumeUsageRow]) -> [Finding] {
        let anonymousNames = Set(volumeNames.filter { $0.Labels.contains("com.docker.volume.anonymous") }.map(\.Name))
        return usage.compactMap { vol in
            guard let bytes = DockerByteSize.bytes(from: vol.size), bytes > 0 else { return nil }
            let isAnonymous = anonymousNames.contains(vol.name)
            let anonymousNote = isAnonymous
                ? String(localized: " (anonymous, no name assigned by a project)")
                : ""
            let explanation = String(
                localized: "Volume \"\(vol.name)\"\(anonymousNote), attached to \(vol.links) containers. WARNING: a volume may hold persistent data (e.g. a database) — always check what it contains before removing it."
            )
            let t = tier("volume", .conditional, .permanent)
            return Finding(
                id: UUID(), domain: .docker, kind: "volume", nodes: [],
                reclaimable: .freedInContainerOnly(bytes), owner: vol.name,
                state: .unknown, risk: t.risk, reversibility: t.reversibility,
                explanation: explanation, comesBack: false
            )
        }
    }

    private func decodeLines<T: Decodable>(_ data: Data, as type: T.Type) throws -> [T] {
        let text = String(decoding: data, as: UTF8.self)
        let decoder = JSONDecoder()
        return text.split(separator: "\n").compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, let d = trimmed.data(using: .utf8) else { return nil }
            return try? decoder.decode(T.self, from: d)
        }
    }
}
