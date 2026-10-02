//
//  DeletionController.swift
//  Lucent
//
//  Created by Amine ben moussa on 29/07/26.
//

import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class DeletionController {

    private(set) var lastResult: [UUID: DeletionResult] = [:]
    private(set) var lastError: String?
    private(set) var working: Set<UUID> = []

    private let executor: DeletionExecutor
    private let restore: RestoreCoordinator
    private let docker: DockerDeletionService
    private let simulators: SimulatorDeletionService
    private let whatsApp: WhatsAppMediaDeletionService

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
        self.docker = DockerDeletionService()
        self.simulators = SimulatorDeletionService()
        self.whatsApp = WhatsAppMediaDeletionService()
    }

    func canDelete(_ finding: Finding) -> Bool {
        finding.risk != .doNotTouch && finding.isActionable
    }

    func canUndo(_ finding: Finding) -> Bool {
        finding.dockerResource == nil && finding.simulatorResource == nil && finding.whatsAppOrphanChat == nil
    }

    func result(for finding: Finding) -> DeletionResult? { lastResult[finding.id] }

    func isWorking(_ finding: Finding) -> Bool { working.contains(finding.id) }

    func isDeleted(_ finding: Finding) -> Bool {
        lastResult[finding.id]?.isCompleteSuccess == true
    }

    func delete(_ finding: Finding) {
        lastError = nil
        if finding.dockerResource == .reclaimSpace {
            compactDocker(finding)
            return
        }
        if let resource = finding.dockerResource {
            deleteDocker(finding, resource)
            return
        }
        if let resource = finding.simulatorResource {
            deleteSimulator(finding, resource)
            return
        }
        if let chatID = finding.whatsAppOrphanChat {
            deleteWhatsAppMedia(finding, chatID)
            return
        }
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

    func canTrash(_ url: URL) -> Bool {
        let path = url.standardizedFileURL.path
        let home = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL.path
        return url.pathComponents.count > 2
            && path != home
            && path != home + "/Library"
            && !SIPPathValidator().isProtected(path)
    }

    func trash(_ url: URL, physicalSize: Int64) -> Bool {
        lastError = nil
        guard canTrash(url) else { return false }
        let removal = PlannedRemoval(path: url, strategy: .trash, physicalSize: physicalSize,
                                     reclaimable: .returnedToOS(physicalSize))
        let result = executor.execute(DeletionPlan(removals: [removal]))
        lastError = result.failed.first?.message
        return result.isCompleteSuccess
    }

    private func deleteDocker(_ finding: Finding, _ resource: DockerResource) {
        guard finding.risk != .doNotTouch else { return }
        do {
            try docker.remove(resource)
            // No UndoRecord: the removal is final, so the result only marks
            // the finding as done for the UI.
            lastResult[finding.id] = DeletionResult(succeeded: [], failed: [])
        } catch {
            lastError = Self.message(for: error)
        }
    }

    private func compactDocker(_ finding: Finding) {
        working.insert(finding.id)
        Task {
            do {
                try await docker.reclaimSpace()
                lastResult[finding.id] = DeletionResult(succeeded: [], failed: [])
            } catch {
                lastError = Self.message(for: error)
            }
            working.remove(finding.id)
        }
    }

    private func deleteSimulator(_ finding: Finding, _ resource: SimulatorResource) {
        guard finding.risk != .doNotTouch else { return }
        do {
            try simulators.remove(resource)
            lastResult[finding.id] = DeletionResult(succeeded: [], failed: [])
        } catch {
            lastError = Self.message(for: error)
        }
    }

    private func deleteWhatsAppMedia(_ finding: Finding, _ chatID: String) {
        guard NSRunningApplication.runningApplications(withBundleIdentifier: "net.whatsapp.WhatsApp").isEmpty else {
            lastError = String(localized: "Quit WhatsApp first, then try again.")
            return
        }
        do {
            try whatsApp.removeOrphans(chatID: chatID)
            lastResult[finding.id] = DeletionResult(succeeded: [], failed: [])
        } catch WhatsAppMediaError.databaseUnreadable {
            lastError = String(localized: "Lucent couldn't read WhatsApp's database, so nothing was moved.")
        } catch {
            lastError = (error as NSError).localizedDescription
        }
    }

    private static func message(for error: Error) -> String {
        if case let SimctlError.commandFailed(_, stderr) = error {
            let detail = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            return detail.isEmpty ? String(localized: "Xcode refused the removal.") : detail
        }
        guard let cliError = error as? DockerCLIError else {
            return (error as NSError).localizedDescription
        }
        switch cliError {
        case .dockerNotFound:
            return String(localized: "Docker isn't installed, or its CLI isn't where Lucent looks for it.")
        case .commandFailed(_, _, let stderr):
            let detail = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            return detail.isEmpty ? String(localized: "Docker refused the removal.") : detail
        }
    }

    func undo(_ finding: Finding) {
        guard canUndo(finding), let result = lastResult[finding.id] else { return }
        lastError = nil
        do {
            _ = try restore.restore(result.succeeded)
            lastResult[finding.id] = nil
        } catch {
            lastError = (error as NSError).localizedDescription
        }
    }
}
