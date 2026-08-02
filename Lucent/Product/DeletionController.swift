//
//  DeletionController.swift
//  Lucent
//
//  Created by Amine ben moussa on 29/07/26.
//

import Foundation
import Observation

@MainActor
@Observable
final class DeletionController {

    private(set) var lastResult: [UUID: DeletionResult] = [:]
    private(set) var lastError: String?

    private let executor: DeletionExecutor
    private let restore: RestoreCoordinator

    init() {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Lucent", isDirectory: true)
        let log = UndoLog(url: base.appendingPathComponent("undo-log.jsonl"))
        self.executor = DeletionExecutor(
            quarantineDir: base.appendingPathComponent("Quarantine", isDirectory: true),
            undoLog: log
        )
        self.restore = RestoreCoordinator(undoLog: log)
    }

    func canDelete(_ finding: Finding) -> Bool { finding.risk != .doNotTouch }

    func result(for finding: Finding) -> DeletionResult? { lastResult[finding.id] }

    func isDeleted(_ finding: Finding) -> Bool {
        lastResult[finding.id]?.isCompleteSuccess == true
    }

    func delete(_ finding: Finding) {
        lastError = nil
        do {
            let plan = try DeletionIntent(findings: [finding]).dryRun()
            let result = executor.execute(plan)
            lastResult[finding.id] = result
            if !result.isCompleteSuccess {
                lastError = result.failed.first?.message
            }
        } catch {
            lastError = (error as NSError).localizedDescription
        }
    }

    func undo(_ finding: Finding) {
        guard let result = lastResult[finding.id] else { return }
        lastError = nil
        do {
            _ = try restore.restore(result.succeeded)
            lastResult[finding.id] = nil
        } catch {
            lastError = (error as NSError).localizedDescription
        }
    }
}
