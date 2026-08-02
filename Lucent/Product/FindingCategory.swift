//
//  FindingCategory.swift
//  Lucent
//
//  Created by Amine ben moussa on 21/07/26.
//

import Foundation

struct FindingCategory: Identifiable, Hashable {
    let kind: String
    let findings: [Finding]

    var id: String { kind }
    var totalBytes: Int64 { findings.reduce(0) { $0 + $1.reclaimable.bytes } }

    var risk: RiskTier {
        if findings.contains(where: { $0.risk == .doNotTouch }) { return .doNotTouch }
        if findings.contains(where: { $0.risk == .conditional }) { return .conditional }
        return .safe
    }
}
