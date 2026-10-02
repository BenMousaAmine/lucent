import Foundation

struct AIModelProbe: DomainProbe {
    let domain: Domain = .system
    private let ollamaRoot: URL
    private let huggingFaceRoot: URL
    private let ollamaInstalled: Bool
    private let minimumReportableSize: Int64
    private let manifest: RuleManifest

    static var isOllamaInstalled: Bool {
        ["/Applications/Ollama.app", "/usr/local/bin/ollama", "/opt/homebrew/bin/ollama"]
            .contains { FileManager.default.fileExists(atPath: $0) }
    }

    init(ollamaRoot: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".ollama/models"),
         huggingFaceRoot: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".cache/huggingface"),
         ollamaInstalled: Bool = AIModelProbe.isOllamaInstalled,
         minimumReportableSize: Int64 = 10 * 1024 * 1024,
         manifest: RuleManifest = .default) {
        self.ollamaRoot = ollamaRoot
        self.huggingFaceRoot = huggingFaceRoot
        self.ollamaInstalled = ollamaInstalled
        self.minimumReportableSize = minimumReportableSize
        self.manifest = manifest
    }

    func isAvailable() async -> Bool {
        let fm = FileManager.default
        return fm.fileExists(atPath: ollamaRoot.path) || fm.fileExists(atPath: huggingFaceRoot.path)
    }

    func scan() async throws -> [Finding] {
        (ollamaFindings() + huggingFaceFindings()).filter { $0.reclaimable.bytes >= minimumReportableSize }
    }

    private struct OllamaManifest: Decodable {
        struct Layer: Decodable { let digest: String }
        let config: Layer?
        let layers: [Layer]?

        var blobNames: Set<String> {
            Set(([config].compactMap { $0 } + (layers ?? [])).map { $0.digest.replacingOccurrences(of: ":", with: "-") })
        }
    }

    private func ollamaFindings() -> [Finding] {
        let fm = FileManager.default
        let blobsRoot = ollamaRoot.appendingPathComponent("blobs")
        var models: [(name: String, url: URL, blobs: Set<String>)] = []
        if let enumerator = fm.enumerator(at: ollamaRoot.appendingPathComponent("manifests"),
                                          includingPropertiesForKeys: [.isRegularFileKey]) {
            for case let url as URL in enumerator {
                guard (try? url.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true,
                      let data = try? Data(contentsOf: url),
                      let decoded = try? JSONDecoder().decode(OllamaManifest.self, from: data),
                      let name = Self.ollamaName(url) else { continue }
                models.append((name, url, decoded.blobNames))
            }
        }

        var usage: [String: Int] = [:]
        for model in models { for blob in model.blobs { usage[blob, default: 0] += 1 } }

        var findings = models.map { model -> Finding in
            let own = model.blobs.filter { usage[$0] == 1 }.sorted().map { blobsRoot.appendingPathComponent($0) }
            let nodes = ([model.url] + own).compactMap(fileNode)
            let unused = ollamaInstalled
                ? ""
                : String(localized: " Ollama doesn't seem to be installed anymore, so nothing uses it.")
            let explanation = String(
                localized: "\(model.name): an AI model downloaded by Ollama. Removing it frees its space; Ollama downloads it again if you pull or run it.\(unused)"
            )
            return makeFinding(kind: "ollamaModel", owner: model.name, nodes: nodes,
                               risk: .conditional, reversibility: .trash,
                               state: ollamaInstalled ? .stale : .orphan,
                               explanation: explanation, comesBack: false)
        }

        let leftovers = ((try? fm.contentsOfDirectory(atPath: blobsRoot.path)) ?? [])
            .filter { usage[$0] == nil }
            .sorted()
            .compactMap { fileNode(blobsRoot.appendingPathComponent($0)) }
        if !leftovers.isEmpty {
            let explanation = String(
                localized: "\(leftovers.count) files in Ollama's storage that no installed model uses: interrupted downloads and pieces of models already removed."
            )
            findings.append(makeFinding(kind: "ollamaLeftovers", owner: "Ollama", nodes: leftovers,
                                        risk: .safe, reversibility: .trash, state: .orphan,
                                        explanation: explanation, comesBack: false))
        }
        return findings
    }

    private static func ollamaName(_ manifest: URL) -> String? {
        guard let marker = manifest.path.range(of: "/manifests/", options: .backwards) else { return nil }
        var parts = manifest.path[marker.upperBound...].split(separator: "/").map(String.init)
        guard let tag = parts.popLast(), !parts.isEmpty else { return nil }
        if parts.starts(with: ["registry.ollama.ai", "library"]) { parts.removeFirst(2) }
        return parts.joined(separator: "/") + ":" + tag
    }

    private func huggingFaceFindings() -> [Finding] {
        let fm = FileManager.default
        let hub = huggingFaceRoot.appendingPathComponent("hub")
        var findings = ((try? fm.contentsOfDirectory(atPath: hub.path)) ?? []).sorted().compactMap { entry -> Finding? in
            let parts = entry.components(separatedBy: "--")
            guard parts.count >= 2, ["models", "datasets", "spaces"].contains(parts[0]) else { return nil }
            let url = hub.appendingPathComponent(entry)
            let name = parts.dropFirst().joined(separator: "/")
            let changed = (try? fm.attributesOfItem(atPath: url.path)[.modificationDate] as? Date)
                .map { $0.formatted(date: .abbreviated, time: .omitted) } ?? "?"
            let explanation = String(
                localized: "\(name): downloaded through Hugging Face tools into their shared cache, last changed \(changed). A script that needs it downloads it again."
            )
            return makeFinding(kind: "huggingFaceModel", owner: name, nodes: [PathMeasurer().measureDirectory(url)],
                               risk: .conditional, reversibility: .trash, state: .stale,
                               explanation: explanation, comesBack: false)
        }

        let xet = huggingFaceRoot.appendingPathComponent("xet")
        if fm.fileExists(atPath: xet.path) {
            let explanation = String(
                localized: "Hugging Face's download cache. It only speeds up future downloads; the models themselves are stored separately and stay in place."
            )
            findings.append(makeFinding(kind: "huggingFaceCache", owner: "Hugging Face", nodes: [PathMeasurer().measureDirectory(xet)],
                                        risk: .safe, reversibility: .regenerable, state: .stale,
                                        explanation: explanation, comesBack: true))
        }
        return findings
    }

    private func fileNode(_ url: URL) -> FileNode? {
        try? PathMeasurer().measure(url)
    }

    private func makeFinding(
        kind: String, owner: String, nodes: [FileNode], risk: RiskTier, reversibility: Reversibility,
        state: FindingState, explanation: String, comesBack: Bool
    ) -> Finding {
        let tier = manifest.resolved(domain: .system, kind: kind,
                                     fallbackRisk: risk, fallbackReversibility: reversibility)
        return Finding(
            id: UUID(),
            domain: .system,
            kind: kind,
            nodes: nodes,
            reclaimable: .returnedToOS(nodes.reduce(0) { $0 + $1.physicalSize }),
            owner: owner,
            state: state,
            risk: tier.risk,
            reversibility: tier.reversibility,
            explanation: explanation,
            comesBack: comesBack
        )
    }
}
