//
//  RestoreCoordinator.swift
//  Lucent
//
//  Created by Amine ben moussa on 25/07/26.
//

import Foundation

struct RestoreResult: Hashable {
    let restored: [Restored]
    let failed: [Failure]

    struct Restored: Hashable {
        let record: UndoRecord
        let finalPath: URL
    }
    struct Failure: Hashable {
        let record: UndoRecord
        let message: String
    }

    var isCompleteSuccess: Bool { failed.isEmpty }
}

struct RestoreCoordinator {
    let undoLog: UndoLog
    private let fileManager: FileManager

    init(undoLog: UndoLog, fileManager: FileManager = .default) {
        self.undoLog = undoLog
        self.fileManager = fileManager
    }

    func restore(_ records: [UndoRecord]) throws -> RestoreResult {
        var restored: [RestoreResult.Restored] = []
        var failed: [RestoreResult.Failure] = []

        for record in records {
            do {
                let dest = try moveBack(record)
                restored.append(.init(record: record, finalPath: dest))
            } catch {
                failed.append(.init(record: record,
                                    message: (error as NSError).localizedDescription))
            }
        }

        try undoLog.remove(restored.map { $0.record })
        return RestoreResult(restored: restored, failed: failed)
    }

    private func moveBack(_ record: UndoRecord) throws -> URL {
        let source = URL(fileURLWithPath: record.currentPath)
        let target = nonClashingTarget(for: URL(fileURLWithPath: record.originalPath))
        try fileManager.createDirectory(at: target.deletingLastPathComponent(),
                                        withIntermediateDirectories: true)
        try fileManager.moveItem(at: source, to: target)
        return target
    }

    private func nonClashingTarget(for original: URL) -> URL {
        guard fileManager.fileExists(atPath: original.path) else { return original }

        let dir = original.deletingLastPathComponent()
        let ext = original.pathExtension
        let stem = original.deletingPathExtension().lastPathComponent

        func candidate(_ suffix: String) -> URL {
            let name = ext.isEmpty ? "\(stem) \(suffix)" : "\(stem) \(suffix).\(ext)"
            return dir.appendingPathComponent(name)
        }

        var url = candidate("(restored)")
        var n = 2
        while fileManager.fileExists(atPath: url.path) {
            url = candidate("(restored \(n))")
            n += 1
        }
        return url
    }
}
