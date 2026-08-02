//
//  PackageManagerFS.swift
//  Lucent
//
//  Created by Amine ben moussa on 21/07/26.
//

import Foundation

struct PMDirEntry: Equatable {
    let url: URL
    let physicalSize: Int64
}

protocol PackageManagerEnvironment: Sendable {
    func size(of dir: URL) -> Int64?

    func findNodeModules(under root: URL, maxDepth: Int) -> [PMDirEntry]
}

struct RealPackageManagerEnvironment: PackageManagerEnvironment {
    static var home: URL { FileManager.default.homeDirectoryForCurrentUser }

    func size(of dir: URL) -> Int64? {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: dir.path, isDirectory: &isDir), isDir.boolValue else { return nil }
        guard let enumerator = fm.enumerator(
            at: dir, includingPropertiesForKeys: [.totalFileAllocatedSizeKey],
            options: [], errorHandler: nil
        ) else { return 0 }
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            let values = try? fileURL.resourceValues(forKeys: [.totalFileAllocatedSizeKey])
            total += Int64(values?.totalFileAllocatedSize ?? 0)
        }
        return total
    }

    private static let excludedComponents: Set<String> = [".nvm", ".nodenv", ".volta"]

    private static let excludedTopLevelDirs: Set<String> = [
        "Library", "Pictures", "Music", "Movies", "Applications",
        ".Trash", ".cache", "Public",
    ]

    func findNodeModules(under root: URL, maxDepth: Int) -> [PMDirEntry] {
        let fm = FileManager.default
        let rootDepth = root.pathComponents.count
        var results: [PMDirEntry] = []

        guard let topLevelNames = try? fm.contentsOfDirectory(atPath: root.path) else { return [] }
        for name in topLevelNames {
            guard !Self.excludedTopLevelDirs.contains(name), !name.hasPrefix(".") else { continue }
            let subroot = root.appendingPathComponent(name)
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: subroot.path, isDirectory: &isDir), isDir.boolValue else { continue }

            guard let enumerator = fm.enumerator(
                at: subroot, includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles], errorHandler: nil
            ) else { continue }

            for case let url as URL in enumerator {
                let components = url.pathComponents
                let depth = components.count - rootDepth
                if depth > maxDepth { enumerator.skipDescendants(); continue }
                guard components.last == "node_modules" else { continue }
                let parents = components.dropLast()
                if parents.contains("node_modules") { enumerator.skipDescendants(); continue }
                if !Self.excludedComponents.isDisjoint(with: Set(parents)) {
                    enumerator.skipDescendants()
                    continue
                }
                let total = size(of: url) ?? 0
                results.append(PMDirEntry(url: url, physicalSize: total))
                enumerator.skipDescendants()
            }
        }
        return results
    }
}
