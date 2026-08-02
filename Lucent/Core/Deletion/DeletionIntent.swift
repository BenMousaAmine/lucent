//
//  DeletionIntent.swift
//  Lucent
//
//  Created by Amine ben moussa on 24/07/26.
//

import Foundation

struct DeletionIntent {
    let findings: [Finding]

    enum IntentError: Error, Equatable {
        case containsDoNotTouch(kinds: [String])
    }

    init(findings: [Finding]) throws {
        let blocked = findings.filter { $0.risk == .doNotTouch }
        guard blocked.isEmpty else {
            throw IntentError.containsDoNotTouch(kinds: blocked.map { $0.kind })
        }
        self.findings = findings
    }

    func dryRun() -> DeletionPlan {
        let removals = findings.flatMap { finding -> [PlannedRemoval] in
            let strategy = Self.strategy(for: finding.reversibility)
            return finding.nodes.map { node in
                PlannedRemoval(
                    path: node.path,
                    strategy: strategy,
                    physicalSize: node.physicalSize,
                    reclaimable: finding.reclaimable
                )
            }
        }
        return DeletionPlan(removals: removals)
    }

    private static func strategy(for reversibility: Reversibility) -> DeletionStrategy {
        switch reversibility {
        case .trash:                     return .trash
        case .regenerable, .permanent:   return .quarantine
        }
    }
}
