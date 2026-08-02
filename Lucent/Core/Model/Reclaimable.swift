//
//  Reclaimable.swift
//  Lucent
//
//  Created by Amine ben moussa on 21/07/26.
//

import Foundation

enum Reclaimable: Hashable {
    case returnedToOS(Int64)

    case freedInContainerOnly(Int64)

    case blockedBySnapshot(Int64)

    case zero(reason: String)

    var bytes: Int64 {
        switch self {
        case .returnedToOS(let b), .freedInContainerOnly(let b), .blockedBySnapshot(let b):
            return b
        case .zero:
            return 0
        }
    }
}
