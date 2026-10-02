import Testing
import Foundation
@testable import Lucent

@MainActor
struct TrashViewModelTests {

    private func waitUntil(_ condition: () -> Bool) async throws {
        var attempts = 0
        while !condition() && attempts < 500 {
            try await Task.sleep(for: .milliseconds(10))
            attempts += 1
        }
        try #require(condition())
    }

    private func isLoading(_ model: TrashViewModel) -> Bool {
        if case .loading = model.state { return true }
        return false
    }

    @Test("Lists what is in the Trash with sizes, biggest first, and totals it")
    func listsItems() async throws {
        let trash = FileManager.default.temporaryDirectory
            .appendingPathComponent("LucentTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: trash.appendingPathComponent("old-project"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: trash) }
        try Data(repeating: 1, count: 200_000).write(to: trash.appendingPathComponent("old-project/big.bin"))
        try Data(repeating: 2, count: 10_000).write(to: trash.appendingPathComponent("note.txt"))
        try Data(repeating: 3, count: 10).write(to: trash.appendingPathComponent(".DS_Store"))

        let model = TrashViewModel(trashURL: trash)
        model.refresh()
        try await waitUntil { !isLoading(model) }

        #expect(model.items.map(\.name) == ["old-project", "note.txt"])
        #expect(model.totalBytes >= 210_000)
    }

    @Test("An unreadable Trash is reported as no access, never as empty")
    func unreadableIsNotEmpty() async throws {
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("LucentTests-\(UUID().uuidString)", isDirectory: true)

        let model = TrashViewModel(trashURL: missing)
        model.refresh()
        try await waitUntil { !isLoading(model) }

        guard case .noAccess = model.state else {
            Issue.record("expected noAccess")
            return
        }
        #expect(model.items.isEmpty)
    }
}
