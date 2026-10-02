//
//  FindingLabels.swift
//  Lucent
//
//  Created by Amine ben moussa on 21/07/26.
//

import Foundation

enum FindingLabels {
    private static let perElementKinds: Set<String> = [
        "danglingImage", "stoppedContainer", "volume",
        "simulatorRuntime", "lockedSimulatorRuntime", "whatsAppOrphanMedia",
        "ollamaModel", "huggingFaceModel",
        "oldJetBrainsVersion", "androidOldNDK", "androidUnusedSystemImage",
        "nodeModules", "rustTarget", "phpVendor", "cocoaPods", "carthage", "pythonVenv", "pythonVenvEnv",
    ]

    static func title(_ finding: Finding) -> String {
        if perElementKinds.contains(finding.kind), let owner = finding.owner {
            return owner
        }
        return kindLabel(finding)
    }

    static func kindLabel(_ finding: Finding) -> String {
        switch finding.kind {
        case "danglingImage": return String(localized: "Unused image")
        case "buildCache": return String(localized: "Build cache")
        case "stoppedContainer": return String(localized: "Stopped container")
        case "volume": return String(localized: "Volume")
        case "dockerDiskCompaction": return String(localized: "Docker disk compaction")
        case "derivedData": return "DerivedData"
        case "archives": return String(localized: "Archives")
        case "deviceSupport": return "Device Support"
        case "simulators": return String(localized: "Simulators")
        case "simulatorRuntime": return String(localized: "Simulator system")
        case "lockedSimulatorRuntime": return String(localized: "Simulator system kept by macOS")
        case "unavailableSimulators": return String(localized: "Simulators that can't start")
        case "npmCache": return String(localized: "npm cache")
        case "pnpmCache": return String(localized: "pnpm cache")
        case "pipCache": return String(localized: "pip cache")
        case "yarnCache": return String(localized: "Yarn cache")
        case "nodeModules": return "node_modules"
        case "rustTarget": return String(localized: "Rust build output")
        case "phpVendor": return String(localized: "Composer vendor")
        case "cocoaPods": return "Pods"
        case "carthage": return "Carthage"
        case "pythonVenv", "pythonVenvEnv": return String(localized: "Python virtualenv")
        case "orphanContainer": return String(localized: "Uninstalled app")
        case "thirdPartyCaches": return String(localized: "Third-party app caches")
        case "whatsAppOrphanMedia": return String(localized: "WhatsApp media no longer in any chat")
        case "whatsAppAccessNeeded": return String(localized: "WhatsApp: access needed")
        case "ollamaModel": return String(localized: "Ollama model")
        case "ollamaLeftovers": return String(localized: "Ollama leftover files")
        case "huggingFaceModel": return String(localized: "Hugging Face model")
        case "huggingFaceCache": return String(localized: "Hugging Face download cache")
        case "ideCrashDump": return String(localized: "IDE crash dumps")
        case "oldJetBrainsVersion": return String(localized: "Old JetBrains version data")
        case "androidOldNDK": return String(localized: "Older Android NDK")
        case "androidUnusedSystemImage": return String(localized: "Unused Android emulator image")
        case "arduinoDownloads": return String(localized: "Arduino downloads")
        default: return finding.kind
        }
    }

    static func reclaimText(_ reclaimable: Reclaimable) -> String {
        switch reclaimable {
        case .freedInContainerOnly(let b):
            return "\(ByteCountFormatter.string(fromByteCount: b, countStyle: .file)) \(String(localized: "(in the VM)"))"
        case .returnedToOS(let b):
            return ByteCountFormatter.string(fromByteCount: b, countStyle: .file)
        case .blockedBySnapshot(let b):
            return "\(ByteCountFormatter.string(fromByteCount: b, countStyle: .file)) \(String(localized: "(blocked)"))"
        case .zero(let reason):
            return "≈ 0 (\(reason))"
        }
    }
}
