//
//  RuleManifest+Default.swift
//  Lucent
//
//  Created by Amine ben moussa on 29/07/26.
//

import Foundation

extension RuleManifest {

    static let `default` = RuleManifest(
        version: 1,
        rules: [
            Domain.xcode.rawValue: [
                "derivedData":  TieringRule(risk: .safe,        reversibility: .regenerable),
                "archives":     TieringRule(risk: .doNotTouch,  reversibility: .permanent),
                "deviceSupport":TieringRule(risk: .conditional, reversibility: .regenerable),
                "simulators":   TieringRule(risk: .conditional, reversibility: .permanent),
            ],
            Domain.docker.rawValue: [
                "danglingImage":  TieringRule(risk: .safe,        reversibility: .regenerable),
                "buildCache":     TieringRule(risk: .safe,        reversibility: .regenerable),
                "stoppedContainer":TieringRule(risk: .conditional, reversibility: .permanent),
                "volume":         TieringRule(risk: .conditional, reversibility: .permanent),
            ],
            Domain.packageManager.rawValue: [
                "npmCache":     TieringRule(risk: .safe,        reversibility: .regenerable),
                "pnpmCache":    TieringRule(risk: .safe,        reversibility: .regenerable),
                "pipCache":     TieringRule(risk: .safe,        reversibility: .regenerable),
                "yarnCache":    TieringRule(risk: .safe,        reversibility: .regenerable),
                "nodeModules":  TieringRule(risk: .conditional, reversibility: .regenerable),
            ],
            Domain.orphanApp.rawValue: [
                "orphanContainer": TieringRule(risk: .conditional, reversibility: .permanent),
            ],
            Domain.system.rawValue: [
                "thirdPartyCaches": TieringRule(risk: .safe, reversibility: .regenerable),
            ],
        ]
    )
}
