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
    let lastModified: Date?

    init(url: URL, physicalSize: Int64, lastModified: Date? = nil) {
        self.url = url
        self.physicalSize = physicalSize
        self.lastModified = lastModified
    }
}

struct DependencyMarker: Equatable {
    let kind: String
    let ecosystem: String
    let dirName: String
    let siblingManifests: [String]
    let regenerateCommand: String
}

protocol PackageManagerEnvironment: Sendable {
    func size(of dir: URL) -> Int64?

    func findDependencyDirs(marker: DependencyMarker, under root: URL, maxDepth: Int) -> [PMDirEntry]
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

    private func hasSiblingManifest(_ url: URL, _ manifests: [String]) -> Bool {
        guard !manifests.isEmpty else { return true }
        let fm = FileManager.default
        let parent = url.deletingLastPathComponent()
        return manifests.contains { fm.fileExists(atPath: parent.appendingPathComponent($0).path) }
    }

    /// Most recent activity of the project owning `dependencyDir`: the newest mtime
    /// between the project folder and the dependency dir itself.
    private func projectModified(_ dependencyDir: URL) -> Date? {
        let fm = FileManager.default
        let project = dependencyDir.deletingLastPathComponent()
        let dates = [project, dependencyDir].compactMap {
            (try? fm.attributesOfItem(atPath: $0.path))?[.modificationDate] as? Date
        }
        return dates.max()
    }

    func findDependencyDirs(marker: DependencyMarker, under root: URL, maxDepth: Int) -> [PMDirEntry] {
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
                guard components.last == marker.dirName else { continue }
                let parents = components.dropLast()
                if parents.contains(marker.dirName) { enumerator.skipDescendants(); continue }
                if !Self.excludedComponents.isDisjoint(with: Set(parents)) {
                    enumerator.skipDescendants()
                    continue
                }
                guard hasSiblingManifest(url, marker.siblingManifests) else {
                    enumerator.skipDescendants()
                    continue
                }
                let total = size(of: url) ?? 0
                results.append(PMDirEntry(url: url, physicalSize: total, lastModified: projectModified(url)))
                enumerator.skipDescendants()
            }
        }
        return results
    }
}
