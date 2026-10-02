import Testing
import Foundation
@testable import Lucent

@MainActor
struct ScanViewModelTests {

    private func makeTree() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("LucentTests-\(UUID().uuidString)", isDirectory: true)
        let nested = dir.appendingPathComponent("bigdir/nested")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try Data(repeating: 1, count: 100_000).write(to: dir.appendingPathComponent("bigdir/x.bin"))
        try Data(repeating: 2, count: 100_000).write(to: nested.appendingPathComponent("y.bin"))
        return dir
    }

    private func waitUntil(_ condition: () -> Bool) async throws {
        var attempts = 0
        while !condition() && attempts < 500 {
            try await Task.sleep(for: .milliseconds(10))
            attempts += 1
        }
        try #require(condition())
    }

    @Test("A finished scan is saved and reloaded without rescanning")
    func reloadsSavedScan() async throws {
        let dir = try makeTree()
        defer { try? FileManager.default.removeItem(at: dir) }
        let cache = FileManager.default.temporaryDirectory
            .appendingPathComponent("LucentTests-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: cache) }

        let first = ScanViewModel(cacheURL: cache)
        first.start(root: dir)
        try await waitUntil { first.phase == .results && FileManager.default.fileExists(atPath: cache.path) }

        try Data(repeating: 3, count: 10_000).write(to: dir.appendingPathComponent("added.bin"))

        let second = ScanViewModel(cacheURL: cache)
        second.start(root: dir)
        try await waitUntil { second.phase == .results }

        #expect(second.scannedAt != nil)
        #expect(second.physicalBytes == first.physicalBytes)
        #expect(Set(second.children.map(\.name)) == Set(first.children.map(\.name)))
        #expect(!second.children.contains { $0.name == "added.bin" })
    }

    @Test("Removing an item shrinks every enclosing folder")
    func removeUpdatesAncestors() async throws {
        let dir = try makeTree()
        defer { try? FileManager.default.removeItem(at: dir) }

        let model = ScanViewModel()
        model.start(root: dir)
        try await waitUntil { model.phase == .results }
        let bigdirBefore = try #require(model.children.first { $0.name == "bigdir" })
        let totalBefore = model.physicalBytes

        model.enter(bigdirBefore)
        try await waitUntil { !model.children.isEmpty }
        let file = try #require(model.children.first { $0.name == "x.bin" })
        model.remove(file)
        #expect(!model.children.contains { $0.name == "x.bin" })

        model.goBack()
        let bigdirAfter = try #require(model.children.first { $0.name == "bigdir" })
        #expect(bigdirAfter.physicalTotal == bigdirBefore.physicalTotal - file.physicalTotal)
        #expect(model.physicalBytes == totalBefore - file.physicalTotal)
        #expect(bigdirAfter.children?.contains { $0.name == "x.bin" } == false)
    }
}
