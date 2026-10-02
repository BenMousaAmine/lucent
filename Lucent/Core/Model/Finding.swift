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
    case devTools
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

/// A resource that lives inside Docker's VM rather than on the filesystem,
/// so it is removed by a CLI command instead of a file move.
enum DockerResource: Hashable {
    case image(id: String)
    case container(id: String)
    case volume(name: String)
    case buildCache
    case reclaimSpace
}

enum SimulatorResource: Hashable {
    case runtime(identifier: String)
    case unavailableDevices
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

    /// Set only for Docker findings, whose bytes live in the VM and have no
    /// path to move: they are removed by a CLI command instead.
    let dockerResource: DockerResource?

    let simulatorResource: SimulatorResource?

    let whatsAppOrphanChat: String?

    init(
        id: UUID,
        domain: Domain,
        kind: String,
        nodes: [FileNode],
        reclaimable: Reclaimable,
        owner: String?,
        state: FindingState,
        risk: RiskTier,
        reversibility: Reversibility,
        explanation: String,
        comesBack: Bool?,
        dockerResource: DockerResource? = nil,
        simulatorResource: SimulatorResource? = nil,
        whatsAppOrphanChat: String? = nil
    ) {
        self.id = id
        self.domain = domain
        self.kind = kind
        self.nodes = nodes
        self.reclaimable = reclaimable
        self.owner = owner
        self.state = state
        self.risk = risk
        self.reversibility = reversibility
        self.explanation = explanation
        self.comesBack = comesBack
        self.dockerResource = dockerResource
        self.simulatorResource = simulatorResource
        self.whatsAppOrphanChat = whatsAppOrphanChat
    }

    /// True when the app can actually carry out a removal for this Finding.
    var isActionable: Bool {
        !nodes.isEmpty || dockerResource != nil || simulatorResource != nil || whatsAppOrphanChat != nil
    }
}
