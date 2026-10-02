//
//  SystemCacheFS.swift
//  Lucent
//
//  Created by Amine ben moussa on 21/07/26.
//

import AppKit
import Foundation

struct CacheEntry: Equatable {
    let name: String
    let physicalSize: Int64
    let url: URL

    init(name: String, physicalSize: Int64, url: URL? = nil) {
        self.name = name
        self.physicalSize = physicalSize
        self.url = url ?? RealSystemCacheEnvironment.home
            .appendingPathComponent("Library/Caches/\(name)")
    }
}

struct RunningApp: Equatable {
    let bundleIdentifier: String
    let name: String
}

protocol SystemCacheEnvironment: Sendable {
    func cacheEntries() -> [CacheEntry]

    func runningApps() -> [RunningApp]
}

extension SystemCacheEnvironment {
    func runningApps() -> [RunningApp] { [] }
}

struct RealSystemCacheEnvironment: SystemCacheEnvironment {
    static var home: URL { FileManager.default.homeDirectoryForCurrentUser }

    func cacheEntries() -> [CacheEntry] {
        let fm = FileManager.default
        let root = Self.home.appendingPathComponent("Library/Caches")
        guard let names = try? fm.contentsOfDirectory(atPath: root.path) else { return [] }
        return names.compactMap { name in
            let url = root.appendingPathComponent(name)
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else { return nil }
            return CacheEntry(name: name, physicalSize: physicalSize(of: url), url: url)
        }
    }

    func runningApps() -> [RunningApp] {
        NSWorkspace.shared.runningApplications.compactMap { app in
            app.bundleIdentifier.map { RunningApp(bundleIdentifier: $0, name: app.localizedName ?? "") }
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
