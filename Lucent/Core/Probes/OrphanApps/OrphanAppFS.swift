//
//  OrphanAppFS.swift
//  Lucent
//
//  Created by Amine ben moussa on 21/07/26.
//

import Foundation

struct ContainerEntry: Equatable {
    let bundleID: String
    let physicalSize: Int64
    let lastModified: Date?
}

protocol OrphanAppEnvironment: Sendable {
    func installedBundleIDs() -> Set<String>

    func containers() -> [ContainerEntry]
}

struct RealOrphanAppEnvironment: OrphanAppEnvironment {
    static var home: URL { FileManager.default.homeDirectoryForCurrentUser }

    private static let appDirs = [
        "/Applications",
        "/System/Applications",
        "/Applications/Utilities",
    ]

    func installedBundleIDs() -> Set<String> {
        let fm = FileManager.default
        var ids = Set<String>()
        for dir in Self.appDirs {
            guard let names = try? fm.contentsOfDirectory(atPath: dir) else { continue }
            for name in names where name.hasSuffix(".app") {
                let path = "\(dir)/\(name)"
                if let id = bundleID(atPath: path) { ids.insert(id) }
            }
        }
        return ids
    }

    private func bundleID(atPath path: String) -> String? {
        guard let bundle = Bundle(path: path) else { return nil }
        return bundle.bundleIdentifier
    }

    func containers() -> [ContainerEntry] {
        let fm = FileManager.default
        let root = Self.home.appendingPathComponent("Library/Containers")
        guard let names = try? fm.contentsOfDirectory(atPath: root.path) else { return [] }
        return names.compactMap { name in
            let url = root.appendingPathComponent(name)
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else { return nil }
            let attrs = try? fm.attributesOfItem(atPath: url.path)
            let modified = attrs?[.modificationDate] as? Date
            return ContainerEntry(bundleID: name, physicalSize: physicalSize(of: url), lastModified: modified)
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
}
