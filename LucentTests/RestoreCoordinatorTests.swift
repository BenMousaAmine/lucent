//
//  RestoreCoordinatorTests.swift
//  Lucent
//
//  Created by Amine ben moussa on 25/07/26.
//

import Testing
import Foundation
@testable import Lucent

struct RestoreCoordinatorTests {

    private func makeFile(_ url: URL, _ content: String) throws {
        try content.data(using: .utf8)!.write(to: url)
    }

    private func quarantineDelete(_ source: URL, on volume: DisposableAPFSVolume)
        throws -> (UndoLog, UndoRecord) {
        let quarantine = volume.mountPoint.appendingPathComponent("Quarantine", isDirectory: true)
        let log = UndoLog(url: volume.mountPoint.appendingPathComponent("undo.jsonl"))
        let executor = DeletionExecutor(quarantineDir: quarantine, undoLog: log)
        let plan = DeletionPlan(removals: [
            PlannedRemoval(path: source, strategy: .quarantine,
                           physicalSize: 10, reclaimable: .returnedToOS(10))
        ])
        let result = executor.execute(plan)
        return (log, result.succeeded[0])
    }

    @Test("Round trip: delete then restore puts the file back and clears the log")
    func roundTrip() throws {
        let volume = try DisposableAPFSVolume(); defer { volume.destroy() }
        let source = volume.mountPoint.appendingPathComponent("notes.txt")
        try makeFile(source, "hello")

        let (log, record) = try quarantineDelete(source, on: volume)
        #expect(!FileManager.default.fileExists(atPath: source.path))

        let restore = RestoreCoordinator(undoLog: log)
        let result = try restore.restore([record])

        #expect(result.isCompleteSuccess)
        let landed = try #require(result.restored.first?.finalPath)
        #expect(landed.path == source.path)
        #expect(FileManager.default.fileExists(atPath: source.path))
        #expect(try log.readAll().isEmpty)
    }

    @Test("Conflict: occupied origin restores as a (restored) variant, no overwrite")
    func conflictKeepsBoth() throws {
        let volume = try DisposableAPFSVolume(); defer { volume.destroy() }
        let source = volume.mountPoint.appendingPathComponent("data.txt")
        try makeFile(source, "OLD")

        let (log, record) = try quarantineDelete(source, on: volume)
        try makeFile(source, "NEW")

        let restore = RestoreCoordinator(undoLog: log)
        let result = try restore.restore([record])

        let landed = try #require(result.restored.first?.finalPath)
        #expect(landed != source)
        #expect(landed.lastPathComponent == "data (restored).txt")
        #expect(try String(contentsOf: source, encoding: .utf8) == "NEW")
        #expect(try String(contentsOf: landed, encoding: .utf8) == "OLD")
    }

    @Test("Failure leaves the record in the log for retry")
    func failedRestoreKeepsRecord() throws {
        let volume = try DisposableAPFSVolume(); defer { volume.destroy() }
        let source = volume.mountPoint.appendingPathComponent("gone.txt")
        try makeFile(source, "x")
        let (log, record) = try quarantineDelete(source, on: volume)

        try FileManager.default.removeItem(atPath: record.currentPath)

        let restore = RestoreCoordinator(undoLog: log)
        let result = try restore.restore([record])

        #expect(result.restored.isEmpty)
        #expect(result.failed.count == 1)
        #expect(try log.readAll().count == 1)
    }
}
