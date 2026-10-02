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
                "simulatorRuntime":       TieringRule(risk: .conditional, reversibility: .permanent),
                "lockedSimulatorRuntime": TieringRule(risk: .doNotTouch,  reversibility: .permanent),
                "unavailableSimulators":  TieringRule(risk: .safe,        reversibility: .permanent),
            ],
            Domain.docker.rawValue: [
                "danglingImage":  TieringRule(risk: .safe,        reversibility: .regenerable),
                "buildCache":     TieringRule(risk: .safe,        reversibility: .regenerable),
                "stoppedContainer":TieringRule(risk: .conditional, reversibility: .permanent),
                "volume":         TieringRule(risk: .conditional, reversibility: .permanent),
                "dockerDiskCompaction": TieringRule(risk: .safe, reversibility: .regenerable),
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
            Domain.devTools.rawValue: [
                "ideCrashDump":             TieringRule(risk: .safe,        reversibility: .trash),
                "oldJetBrainsVersion":      TieringRule(risk: .conditional, reversibility: .trash),
                "androidOldNDK":            TieringRule(risk: .conditional, reversibility: .regenerable),
                "androidUnusedSystemImage": TieringRule(risk: .conditional, reversibility: .regenerable),
                "arduinoDownloads":         TieringRule(risk: .safe,        reversibility: .regenerable),
            ],
            Domain.system.rawValue: [
                "thirdPartyCaches": TieringRule(risk: .safe, reversibility: .regenerable),
                "whatsAppOrphanMedia": TieringRule(risk: .safe, reversibility: .trash),
                "ollamaModel":      TieringRule(risk: .conditional, reversibility: .trash),
                "ollamaLeftovers":  TieringRule(risk: .safe,        reversibility: .trash),
                "huggingFaceModel": TieringRule(risk: .conditional, reversibility: .trash),
                "huggingFaceCache": TieringRule(risk: .safe,        reversibility: .regenerable),
            ],
        ]
    )
}
