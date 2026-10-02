//
//  DeletionExecutor.swift
//  Lucent
//
//  Created by Amine ben moussa on 25/07/26.
//

import Foundation

struct DeletionResult: Hashable {
    let succeeded: [UndoRecord]
    let failed: [Failure]

    struct Failure: Hashable {
        let path: URL
        let message: String
    }

    var isCompleteSuccess: Bool { failed.isEmpty }
    var reclaimedBytes: Int64 { succeeded.reduce(0) { $0 + $1.physicalSize } }
}

struct DeletionExecutor {
    let quarantineDir: URL
    let undoLog: UndoLog
    private let fileManager: FileManager

    init(quarantineDir: URL, undoLog: UndoLog, fileManager: FileManager = .default) {
        self.quarantineDir = quarantineDir
        self.undoLog = undoLog
        self.fileManager = fileManager
    }

    func execute(_ plan: DeletionPlan) -> DeletionResult {
        var succeeded: [UndoRecord] = []
        var failed: [DeletionResult.Failure] = []

        for removal in plan.removals {
            do {
                let record = try perform(removal)
                try undoLog.append(record)
                succeeded.append(record)
            } catch {
                failed.append(.init(path: removal.path,
                                    message: (error as NSError).localizedDescription))
            }
        }
        return DeletionResult(succeeded: succeeded, failed: failed)
    }

    private func perform(_ removal: PlannedRemoval) throws -> UndoRecord {
        let destination: URL
        switch removal.strategy {
        case .trash:
            var trashed: NSURL?
            try fileManager.trashItem(at: removal.path, resultingItemURL: &trashed)
            destination = (trashed as URL?) ?? removal.path
        case .quarantine:
            try fileManager.createDirectory(at: quarantineDir,
                                            withIntermediateDirectories: true)
            let target = nonClashingTarget(named: removal.path.lastPathComponent)
            try fileManager.moveItem(at: removal.path, to: target)
            destination = target
        }

        return UndoRecord(
            originalPath: removal.path.path,
            currentPath: destination.path,
            strategy: removal.strategy,
            physicalSize: removal.physicalSize
        )
    }

    /// Quarantined items keep their original name, which collides across
    /// projects (every one of them is a "node_modules").
    private func nonClashingTarget(named name: String) -> URL {
        let url = quarantineDir.appendingPathComponent(name)
        guard fileManager.fileExists(atPath: url.path) else { return url }

        var n = 2
        var candidate = quarantineDir.appendingPathComponent("\(name) (\(n))")
        while fileManager.fileExists(atPath: candidate.path) {
            n += 1
            candidate = quarantineDir.appendingPathComponent("\(name) (\(n))")
        }
        return candidate
    }
}
