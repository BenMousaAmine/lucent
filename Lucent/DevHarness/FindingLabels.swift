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
        case "derivedData": return "DerivedData"
        case "archives": return String(localized: "Archives")
        case "deviceSupport": return "Device Support"
        case "simulators": return String(localized: "Simulators")
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
