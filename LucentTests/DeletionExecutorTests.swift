//
//  DeletionExecutorTests.swift
//  Lucent
//
//  Created by Amine ben moussa on 25/07/26.
//

import Testing
import Foundation
@testable import Lucent

struct DeletionExecutorTests {

    private func makeFile(_ url: URL, bytes: Int) throws {
        try Data(repeating: 0x41, count: bytes).write(to: url)
    }

    private func removal(_ path: URL, _ strategy: DeletionStrategy, size: Int64) -> PlannedRemoval {
        PlannedRemoval(path: path, strategy: strategy, physicalSize: size,
                       reclaimable: .returnedToOS(size))
    }

    @Test("Quarantine: file moved off origin into quarantine dir, logged for undo")
    func quarantineMovesAndLogs() throws {
        let volume = try DisposableAPFSVolume()
        defer { volume.destroy() }

        let source = volume.mountPoint.appendingPathComponent("cache.bin")
        try makeFile(source, bytes: 2_048)

        let quarantine = volume.mountPoint.appendingPathComponent("Quarantine", isDirectory: true)
        let log = UndoLog(url: volume.mountPoint.appendingPathComponent("undo.jsonl"))
        let executor = DeletionExecutor(quarantineDir: quarantine, undoLog: log)

        let plan = DeletionPlan(removals: [removal(source, .quarantine, size: 2_048)])
        let result = executor.execute(plan)

        #expect(result.isCompleteSuccess)
        #expect(!FileManager.default.fileExists(atPath: source.path))
        let moved = quarantine.appendingPathComponent("cache.bin")
        #expect(FileManager.default.fileExists(atPath: moved.path))
        let logged = try log.readAll()
        #expect(logged.count == 1)
        #expect(logged.first?.originalPath == source.path)
        #expect(logged.first?.currentPath == moved.path)
    }

    @Test("Partial failure: missing path fails, the valid one still succeeds")
    func partialFailureContinues() throws {
        let volume = try DisposableAPFSVolume()
        defer { volume.destroy() }

        let good = volume.mountPoint.appendingPathComponent("real.bin")
        try makeFile(good, bytes: 1_000)
        let missing = volume.mountPoint.appendingPathComponent("does-not-exist.bin")

        let quarantine = volume.mountPoint.appendingPathComponent("Quarantine", isDirectory: true)
        let log = UndoLog(url: volume.mountPoint.appendingPathComponent("undo.jsonl"))
        let executor = DeletionExecutor(quarantineDir: quarantine, undoLog: log)

        let plan = DeletionPlan(removals: [
            removal(missing, .quarantine, size: 1_000),
            removal(good, .quarantine, size: 1_000),
        ])
        let result = executor.execute(plan)

        #expect(result.succeeded.count == 1)
        #expect(result.failed.count == 1)
        #expect(result.failed.first?.path == missing)
        #expect(result.succeeded.first?.originalPath == good.path)
        #expect(try log.readAll().count == 1)
    }

    @Test("Trash: source removed from origin, an undo record returned")
    func trashRemovesSource() throws {
        let volume = try DisposableAPFSVolume()
        defer { volume.destroy() }

        let source = volume.mountPoint.appendingPathComponent("junk.log")
        try makeFile(source, bytes: 512)

        let quarantine = volume.mountPoint.appendingPathComponent("Quarantine", isDirectory: true)
        let log = UndoLog(url: volume.mountPoint.appendingPathComponent("undo.jsonl"))
        let executor = DeletionExecutor(quarantineDir: quarantine, undoLog: log)

        let plan = DeletionPlan(removals: [removal(source, .trash, size: 512)])
        let result = executor.execute(plan)

        #expect(result.isCompleteSuccess)
        #expect(!FileManager.default.fileExists(atPath: source.path))
        if let dest = result.succeeded.first?.currentPath {
            try? FileManager.default.removeItem(atPath: dest)
        }
    }
}
