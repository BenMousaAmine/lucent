//
//  DisposableAPFSVolume.swift
//  Lucent
//
//  Created by Amine ben moussa on 02/06/26.
//

import Foundation

struct DisposableAPFSVolume {
    let mountPoint: URL
    private let imagePath: URL
    private let devEntry: String

    init(sizeMB: Int = 200) throws {
        let tmp = FileManager.default.temporaryDirectory
        let volName = "LucentTest-\(UUID().uuidString.prefix(8))"
        let image = tmp.appendingPathComponent("\(volName).sparseimage")

        try Self.run("/usr/bin/hdiutil", [
            "create", "-size", "\(sizeMB)m", "-fs", "APFS",
            "-type", "SPARSE", "-volname", volName, image.path
        ])

        let plist = try Self.run("/usr/bin/hdiutil", [
            "attach", image.path, "-plist", "-nobrowse"
        ])

        let (dev, mount) = try Self.parseAttach(plist: plist)
        self.imagePath = image
        self.devEntry = dev
        self.mountPoint = URL(fileURLWithPath: mount, isDirectory: true)
    }

    func destroy() {
        _ = try? Self.run("/usr/bin/hdiutil", ["detach", devEntry, "-force"])
        try? FileManager.default.removeItem(at: imagePath)
    }

    // MARK: - Helpers

    @discardableResult
    private static func run(_ launchPath: String, _ args: [String]) throws -> Data {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: launchPath)
        proc.arguments = args
        let out = Pipe()
        proc.standardOutput = out
        proc.standardError = Pipe()
        try proc.run()
        let data = out.fileHandleForReading.readDataToEndOfFile()
        proc.waitUntilExit()
        guard proc.terminationStatus == 0 else {
            throw VolumeError.commandFailed(launchPath, args, proc.terminationStatus)
        }
        return data
    }

    private static func parseAttach(plist: Data) throws -> (dev: String, mount: String) {
        let obj = try PropertyListSerialization.propertyList(from: plist, options: [], format: nil)
        guard
            let dict = obj as? [String: Any],
            let entities = dict["system-entities"] as? [[String: Any]]
        else { throw VolumeError.plistParse }

        for e in entities {
            if let mount = e["mount-point"] as? String,
               let dev = e["dev-entry"] as? String {
                return (dev, mount)
            }
        }
        throw VolumeError.noMountPoint
    }

    enum VolumeError: Error {
        case commandFailed(String, [String], Int32)
        case plistParse
        case noMountPoint
    }
}
