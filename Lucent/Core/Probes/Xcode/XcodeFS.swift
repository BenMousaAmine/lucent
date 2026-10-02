//
//  XcodeFS.swift
//  Lucent
//
//  Created by Amine ben moussa on 21/07/26.
//

import Foundation

struct XcodeDirEntry: Equatable {
    let url: URL
    let physicalSize: Int64
    let lastModified: Date?
}

struct SimulatorRuntimeAsset: Equatable {
    let url: URL
    let platform: String
    let build: String
    let version: String
    let physicalSize: Int64
    let isOfferedByApple: Bool

    var displayName: String { "\(platform) \(version) (\(build))" }

    static func displayPlatform(_ name: String) -> String {
        name == "xrOS" ? "visionOS" : name
    }
}

protocol XcodeEnvironment: Sendable {
    func subdirectories(of dir: URL) -> [XcodeDirEntry]

    func simulatorDevices() throws -> Data

    func simulatorRuntimes() throws -> Data

    func simulatorRuntimeAssets() -> [SimulatorRuntimeAsset]
}

struct RealXcodeEnvironment: XcodeEnvironment {
    static var developerRoot: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Developer/Xcode")
    }

    static let runtimeAssetsRoot = URL(fileURLWithPath: "/System/Library/AssetsV2")

    func subdirectories(of dir: URL) -> [XcodeDirEntry] {
        let fm = FileManager.default
        guard let names = try? fm.contentsOfDirectory(atPath: dir.path) else { return [] }
        return names.compactMap { name in
            let url = dir.appendingPathComponent(name)
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else { return nil }
            let attrs = try? fm.attributesOfItem(atPath: url.path)
            let modified = attrs?[.modificationDate] as? Date
            return XcodeDirEntry(url: url, physicalSize: physicalSize(of: url), lastModified: modified)
        }
    }

    private func physicalSize(of url: URL) -> Int64 {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: url, includingPropertiesForKeys: [.totalFileAllocatedSizeKey],
            options: [], errorHandler: nil
        ) else { return 0 }
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            let values = try? fileURL.resourceValues(forKeys: [.totalFileAllocatedSizeKey])
            total += Int64(values?.totalFileAllocatedSize ?? 0)
        }
        return total
    }

    func simulatorDevices() throws -> Data {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        proc.arguments = ["simctl", "list", "devices", "-j"]
        let out = Pipe()
        proc.standardOutput = out
        proc.standardError = Pipe()
        try proc.run()
        let data = out.fileHandleForReading.readDataToEndOfFile()
        proc.waitUntilExit()
        guard proc.terminationStatus == 0 else {
            throw XcodeProbeError.simctlFailed
        }
        return data
    }

    func simulatorRuntimes() throws -> Data {
        try SimctlCommandLineRunner().run(["runtime", "list", "-j"])
    }

    func simulatorRuntimeAssets() -> [SimulatorRuntimeAsset] {
        let fm = FileManager.default
        let prefix = "com_apple_MobileAsset_", suffix = "SimulatorRuntime"
        let types = (try? fm.contentsOfDirectory(atPath: Self.runtimeAssetsRoot.path)) ?? []
        return types.filter { $0.hasPrefix(prefix) && $0.hasSuffix(suffix) }.flatMap { type -> [SimulatorRuntimeAsset] in
            let dir = Self.runtimeAssetsRoot.appendingPathComponent(type)
            let offered = Self.catalogBuilds(dir.appendingPathComponent(type + ".xml"))
            let platform = SimulatorRuntimeAsset.displayPlatform(String(type.dropFirst(prefix.count).dropLast(suffix.count)))
            let names = (try? fm.contentsOfDirectory(atPath: dir.path)) ?? []
            return names.filter { $0.hasSuffix(".asset") }.compactMap { name in
                let url = dir.appendingPathComponent(name)
                guard let info = NSDictionary(contentsOf: url.appendingPathComponent("Info.plist")),
                      let properties = info["MobileAssetProperties"] as? [String: Any],
                      let build = properties["Build"] as? String else { return nil }
                return SimulatorRuntimeAsset(
                    url: url, platform: platform, build: build,
                    version: properties["SimulatorVersion"] as? String ?? "",
                    physicalSize: physicalSize(of: url),
                    isOfferedByApple: offered?.contains(build) ?? true)
            }
        }
    }

    private static func catalogBuilds(_ catalog: URL) -> Set<String>? {
        guard let dict = NSDictionary(contentsOf: catalog),
              let assets = dict["Assets"] as? [[String: Any]] else { return nil }
        return Set(assets.compactMap { $0["Build"] as? String })
    }
}

enum XcodeProbeError: Error, Equatable {
    case simctlFailed
}
