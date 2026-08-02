//
//  Finding.swift
//  Lucent
//
//  Created by Amine ben moussa on 21/07/26.
//

import Foundation

enum Domain: String, Equatable {
    case xcode
    case docker
    case packageManager
    case nodeModules
    case orphanApp
    case system
    case unknown
}

enum RiskTier: String, Equatable {
    case safe
    case conditional
    case doNotTouch
}

enum Reversibility: String, Equatable {
    case trash
    case regenerable
    case permanent
}

enum FindingState: String, Equatable {
    case live
    case stale
    case orphan
    case unknown
}

struct Finding: Hashable {
    let id: UUID
    let domain: Domain
    let kind: String
    let nodes: [FileNode]

    var logicalTotal: Int64 { nodes.reduce(0) { $0 + $1.logicalSize } }
    var physicalTotal: Int64 { nodes.reduce(0) { $0 + $1.physicalSize } }

    let reclaimable: Reclaimable

    let owner: String?
    let state: FindingState
    let risk: RiskTier
    let reversibility: Reversibility
    let explanation: String
    let comesBack: Bool?
}
