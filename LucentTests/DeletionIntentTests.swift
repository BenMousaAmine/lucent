//
//  DeletionIntentTests.swift
//  Lucent
//
//  Created by Amine ben moussa on 24/07/26.
//

import Testing
import Foundation
@testable import Lucent

private enum Make {
    static func finding(
        kind: String,
        risk: RiskTier,
        reversibility: Reversibility,
        physical: Int64,
        reclaimable: Reclaimable
    ) -> Finding {
        let node = FileNode(
            path: URL(fileURLWithPath: "/tmp/lucent-fake/\(kind)"),
            logicalSize: physical,
            physicalSize: physical,
            linkCount: 1
        )
        return Finding(
            id: UUID(), domain: .unknown, kind: kind, nodes: [node],
            reclaimable: reclaimable, owner: nil, state: .stale,
            risk: risk, reversibility: reversibility,
            explanation: "test", comesBack: nil
        )
    }
}

struct DeletionIntentTests {

    @Test("doNotTouch is refused whole — the intent never builds")
    func doNotTouchRefused() throws {
        let safe = Make.finding(kind: "cache", risk: .safe, reversibility: .trash,
                                physical: 100, reclaimable: .returnedToOS(100))
        let locked = Make.finding(kind: "systemFile", risk: .doNotTouch, reversibility: .permanent,
                                  physical: 999, reclaimable: .returnedToOS(999))

        #expect(throws: DeletionIntent.IntentError.containsDoNotTouch(kinds: ["systemFile"])) {
            _ = try DeletionIntent(findings: [safe, locked])
        }
    }

    @Test("Dry-run resolves paths and strategies without touching disk")
    func dryRunResolves() throws {
        let trashable = Make.finding(kind: "derivedData", risk: .safe, reversibility: .trash,
                                     physical: 200, reclaimable: .returnedToOS(200))
        let regen = Make.finding(kind: "npmCache", risk: .conditional, reversibility: .regenerable,
                                 physical: 300, reclaimable: .returnedToOS(300))

        let plan = try DeletionIntent(findings: [trashable, regen]).dryRun()

        #expect(plan.removals.count == 2)
        let byPath = Dictionary(uniqueKeysWithValues: plan.removals.map { ($0.path.lastPathComponent, $0) })
        #expect(byPath["derivedData"]?.strategy == .trash)
        #expect(byPath["npmCache"]?.strategy == .quarantine)

        #expect(!FileManager.default.fileExists(atPath: "/tmp/lucent-fake/derivedData"))
    }

    @Test("reclaimableToOS counts only bytes that truly return to macOS")
    func honestReclaimable() throws {
        let real = Make.finding(kind: "archive", risk: .safe, reversibility: .trash,
                                physical: 1_000, reclaimable: .returnedToOS(1_000))
        let containerOnly = Make.finding(kind: "dockerImage", risk: .conditional, reversibility: .permanent,
                                         physical: 5_000, reclaimable: .freedInContainerOnly(5_000))
        let clone = Make.finding(kind: "clonedFile", risk: .safe, reversibility: .trash,
                                 physical: 800, reclaimable: .zero(reason: "clone"))

        let plan = try DeletionIntent(findings: [real, containerOnly, clone]).dryRun()

        #expect(plan.totalPhysical == 6_800)
        #expect(plan.reclaimableToOS == 1_000)
    }

    @Test("Empty intent yields an empty plan")
    func emptyPlan() throws {
        let plan = try DeletionIntent(findings: []).dryRun()
        #expect(plan.isEmpty)
    }
}
