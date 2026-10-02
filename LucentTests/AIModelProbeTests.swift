import Testing
import Foundation
@testable import Lucent

private enum AIFixture {
    static func make() throws -> (root: URL, ollama: URL, huggingFace: URL) {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("LucentTests-\(UUID().uuidString)", isDirectory: true)
        let ollama = root.appendingPathComponent("ollama/models")
        let huggingFace = root.appendingPathComponent("huggingface")

        func write(_ path: String, under base: URL, _ data: Data) throws {
            let url = base.appendingPathComponent(path)
            try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: url)
        }
        func blob(_ name: String, _ size: Int) throws {
            try write("blobs/sha256-\(name)", under: ollama, Data(repeating: 5, count: size))
        }
        func manifest(_ path: String, config: String, layers: [String]) throws {
            let json = """
            {"config":{"digest":"sha256:\(config)"},"layers":[\(layers.map { "{\"digest\":\"sha256:\($0)\"}" }.joined(separator: ","))]}
            """
            try write("manifests/" + path, under: ollama, Data(json.utf8))
        }

        try manifest("registry.ollama.ai/library/llama/3b", config: "c1", layers: ["shared", "a1"])
        try manifest("hf.co/someone/Model-GGUF/Q4", config: "c2", layers: ["shared", "b1"])
        for (name, size) in [("c1", 1_000), ("a1", 60_000), ("c2", 1_000), ("b1", 90_000), ("shared", 40_000),
                             ("zz-partial", 30_000), ("gone", 20_000)] {
            try blob(name, size)
        }

        try write("hub/models--org--big/blobs/weights", under: huggingFace, Data(repeating: 6, count: 200_000))
        try fm.createDirectory(at: huggingFace.appendingPathComponent("hub/models--org--empty"), withIntermediateDirectories: true)
        try write("xet/chunks/c0", under: huggingFace, Data(repeating: 7, count: 50_000))
        return (root, ollama, huggingFace)
    }
}

struct AIModelProbeTests {

    private func scan(installed: Bool = true) async throws -> ([Finding], URL) {
        let fixture = try AIFixture.make()
        let probe = AIModelProbe(ollamaRoot: fixture.ollama, huggingFaceRoot: fixture.huggingFace,
                                 ollamaInstalled: installed, minimumReportableSize: 10_000)
        return (try await probe.scan(), fixture.root)
    }

    @Test("Each Ollama model owns its manifest and its own blobs; shared blobs belong to nobody")
    func ollamaModels() async throws {
        let (findings, root) = try await scan()
        defer { try? FileManager.default.removeItem(at: root) }

        let models = findings.filter { $0.kind == "ollamaModel" }
        #expect(Set(models.compactMap(\.owner)) == ["llama:3b", "hf.co/someone/Model-GGUF:Q4"])

        let llama = try #require(models.first { $0.owner == "llama:3b" })
        #expect(llama.nodes.map(\.path.lastPathComponent) == ["3b", "sha256-a1", "sha256-c1"])
        #expect(llama.risk == .conditional)
        #expect(llama.state == .stale)
        #expect(!findings.flatMap(\.nodes).contains { $0.path.lastPathComponent == "sha256-shared" })
    }

    @Test("Blobs no model uses are one leftovers item")
    func ollamaLeftovers() async throws {
        let (findings, root) = try await scan()
        defer { try? FileManager.default.removeItem(at: root) }

        let leftovers = try #require(findings.first { $0.kind == "ollamaLeftovers" })
        #expect(leftovers.nodes.map(\.path.lastPathComponent) == ["sha256-gone", "sha256-zz-partial"])
        #expect(leftovers.risk == .safe)
    }

    @Test("Without Ollama installed its models are flagged as orphaned")
    func ollamaNotInstalled() async throws {
        let (findings, root) = try await scan(installed: false)
        defer { try? FileManager.default.removeItem(at: root) }

        #expect(findings.filter { $0.kind == "ollamaModel" }.allSatisfy { $0.state == .orphan })
    }

    @Test("Hugging Face: one item per cached model above the threshold, plus the download cache")
    func huggingFace() async throws {
        let (findings, root) = try await scan()
        defer { try? FileManager.default.removeItem(at: root) }

        let models = findings.filter { $0.kind == "huggingFaceModel" }
        #expect(models.map(\.owner) == ["org/big"])
        #expect(models.first?.nodes.first?.path.lastPathComponent == "models--org--big")
        #expect((models.first?.reclaimable.bytes ?? 0) >= 200_000)

        let cache = try #require(findings.first { $0.kind == "huggingFaceCache" })
        #expect(cache.risk == .safe)
        #expect(cache.reversibility == .regenerable)
        #expect(cache.nodes.first?.path.lastPathComponent == "xet")
    }
}
