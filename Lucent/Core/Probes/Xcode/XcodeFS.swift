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

protocol XcodeEnvironment: Sendable {
    func subdirectories(of dir: URL) -> [XcodeDirEntry]

    func simulatorDevices() throws -> Data
}

struct RealXcodeEnvironment: XcodeEnvironment {
    static var developerRoot: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Developer/Xcode")
    }

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
}

enum XcodeProbeError: Error, Equatable {
    case simctlFailed
}
