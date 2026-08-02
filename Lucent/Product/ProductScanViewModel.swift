//
//  ProductScanViewModel.swift
//  Lucent
//
//  Created by Amine ben moussa on 21/07/26.
//

import Foundation
import Observation

@MainActor
@Observable
final class ProductScanViewModel {

    enum State {
        case idle
        case scanning
        case loaded
    }

    var state: State = .idle
    private(set) var findingsByDomain: [Domain: [Finding]] = [:]

    var sortedDomains: [Domain] {
        findingsByDomain.keys.sorted { totalBytes(for: $0) > totalBytes(for: $1) }
    }

    func totalBytes(for domain: Domain) -> Int64 {
        (findingsByDomain[domain] ?? []).reduce(0) { $0 + $1.reclaimable.bytes }
    }

    func categories(for domain: Domain) -> [FindingCategory] {
        let findings = findingsByDomain[domain] ?? []
        let grouped = Dictionary(grouping: findings, by: \.kind)
        return grouped.map { kind, items in
            FindingCategory(kind: kind, findings: items.sorted { $0.reclaimable.bytes > $1.reclaimable.bytes })
        }.sorted { $0.totalBytes > $1.totalBytes }
    }

    func scan() {
        state = .scanning
        Task {
            async let docker = Self.run(DockerProbe())
            async let xcode = Self.run(XcodeProbe())
            async let packageManager = Self.run(PackageManagerProbe())
            async let orphanApps = Self.run(OrphanAppProbe())
            async let system = Self.run(SystemCacheProbe())

            let results = await [docker, xcode, packageManager, orphanApps, system]
            var grouped: [Domain: [Finding]] = [:]
            for findings in results {
                for finding in findings {
                    grouped[finding.domain, default: []].append(finding)
                }
            }
            for key in grouped.keys {
                grouped[key]?.sort { $0.reclaimable.bytes > $1.reclaimable.bytes }
            }
            self.findingsByDomain = grouped
            self.state = .loaded
        }
    }

    private static func run(_ probe: some DomainProbe) async -> [Finding] {
        guard await probe.isAvailable() else { return [] }
        return (try? await probe.scan()) ?? []
    }
}
