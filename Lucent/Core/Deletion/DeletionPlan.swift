//
//  DeletionPlan.swift
//  Lucent
//
//  Created by Amine ben moussa on 24/07/26.
//

import Foundation

enum DeletionStrategy: String, Hashable, Codable {
    case trash
    case quarantine
}

struct PlannedRemoval: Hashable {
    let path: URL
    let strategy: DeletionStrategy
    let physicalSize: Int64
    let reclaimable: Reclaimable
}

struct DeletionPlan: Hashable {
    let removals: [PlannedRemoval]

    var isEmpty: Bool { removals.isEmpty }

    var totalPhysical: Int64 { removals.reduce(0) { $0 + $1.physicalSize } }

    var reclaimableToOS: Int64 {
        removals.reduce(0) { sum, r in
            if case let .returnedToOS(b) = r.reclaimable { return sum + b }
            return sum
        }
    }
}
