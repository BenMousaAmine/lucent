//
//  DirectoryScanner.swift
//  Lucent
//
//  Created by Amine ben moussa on 11/06/26.
//

import Foundation

struct ScanProgress: Sendable {
    var filesSeen: Int = 0
    var physicalBytes: Int64 = 0
    var skippedPaths: Int = 0
    var currentPath: String = ""
    var children: [ChildTotal]? = nil
}

nonisolated struct ChildTotal: Sendable, Identifiable, Codable {
    let id = UUID()
    let name: String
    let isDirectory: Bool
    var physicalTotal: Int64
    var children: [ChildTotal]? = nil

    enum CodingKeys: String, CodingKey {
        case name, isDirectory, physicalTotal, children
    }
}

actor DirectoryScanner {
    private let enumerator = BulkEnumerator()
    private let retainThreshold: Int64

    private var filesSeen = 0
    private var physicalBytes: Int64 = 0
    private var skippedPaths = 0

    private var countedIDs: Set<UInt64> = []

    private let mountPointsOverride: Set<String>?
    private var mountPoints: Set<String> = []

    init(retainThreshold: Int64 = 10 * 1024 * 1024, mountPoints: Set<String>? = nil) {
        self.retainThreshold = retainThreshold
        self.mountPointsOverride = mountPoints
    }

    nonisolated func scan(root: URL) -> AsyncStream<ScanProgress> {
        AsyncStream { continuation in
            let task = Task {
                await self.run(root: root, continuation: continuation)
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func run(root: URL, continuation: AsyncStream<ScanProgress>.Continuation) async {
        filesSeen = 0; physicalBytes = 0; skippedPaths = 0; countedIDs = []
        mountPoints = (mountPointsOverride ?? Self.systemMountPoints()).subtracting([root.path])

        let topChildren: [BulkEnumerator.Entry]
        do {
            topChildren = try enumerator.enumerate(root)
        } catch {
            continuation.yield(ScanProgress(skippedPaths: 1, currentPath: root.path, children: []))
            continuation.finish()
            return
        }

        var childTotals: [ChildTotal] = []
        for child in Self.systemLast(topChildren, root: root) where !Task.isCancelled {
            childTotals.append(measure(child, continuation: continuation))
        }

        let final = ScanProgress(
            filesSeen: filesSeen, physicalBytes: physicalBytes,
            skippedPaths: skippedPaths, currentPath: "",
            children: childTotals.sorted { $0.physicalTotal > $1.physicalTotal })
        continuation.yield(final)
        continuation.finish()
    }

    private static func systemMountPoints() -> Set<String> {
        var buffer: UnsafeMutablePointer<statfs>?
        let count = getmntinfo(&buffer, MNT_NOWAIT)
        guard count > 0, let buffer else { return [] }
        return Set((0..<Int(count)).map { index in
            withUnsafePointer(to: &buffer[index].f_mntonname) {
                $0.withMemoryRebound(to: CChar.self, capacity: Int(MAXPATHLEN)) { String(cString: $0) }
            }
        })
    }

    private static func systemLast(_ entries: [BulkEnumerator.Entry], root: URL) -> [BulkEnumerator.Entry] {
        guard root.path == "/" else { return entries }
        return entries.filter { $0.name != "System" } + entries.filter { $0.name == "System" }
    }

    private func accountFile(_ node: FileNode) -> Int64 {
        filesSeen += 1
        if node.fileID != 0 {
            if countedIDs.contains(node.fileID) { return 0 }
            countedIDs.insert(node.fileID)
        }
        physicalBytes += node.physicalSize
        return node.physicalSize
    }

    private func measure(_ entry: BulkEnumerator.Entry, continuation: AsyncStream<ScanProgress>.Continuation) -> ChildTotal {
        guard entry.isDirectory else {
            return ChildTotal(name: entry.name, isDirectory: false, physicalTotal: accountFile(entry.node))
        }
        guard !mountPoints.contains(entry.node.path.path) else {
            return ChildTotal(name: entry.name, isDirectory: true, physicalTotal: 0)
        }

        let entries: [BulkEnumerator.Entry]
        do {
            entries = try enumerator.enumerate(entry.node.path)
        } catch {
            skippedPaths += 1
            return ChildTotal(name: entry.name, isDirectory: true, physicalTotal: 0)
        }

        var children: [ChildTotal] = []
        for child in entries where !Task.isCancelled {
            children.append(measure(child, continuation: continuation))
        }
        let total = children.reduce(0) { $0 + $1.physicalTotal }

        continuation.yield(ScanProgress(
            filesSeen: filesSeen, physicalBytes: physicalBytes,
            skippedPaths: skippedPaths, currentPath: entry.node.path.path))
        return ChildTotal(
            name: entry.name, isDirectory: true, physicalTotal: total,
            children: total >= retainThreshold ? children.sorted { $0.physicalTotal > $1.physicalTotal } : nil)
    }
}
