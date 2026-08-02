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

struct ChildTotal: Sendable, Identifiable {
    let id = UUID()
    let name: String
    let url: URL
    let isDirectory: Bool
    let physicalTotal: Int64
}

actor DirectoryScanner {
    private let enumerator = BulkEnumerator()

    private var filesSeen = 0
    private var physicalBytes: Int64 = 0
    private var skippedPaths = 0

    private var countedIDs: Set<UInt64> = []

    nonisolated func scan(root: URL) -> AsyncStream<ScanProgress> {
        AsyncStream { continuation in
            Task {
                await self.run(root: root, continuation: continuation)
            }
        }
    }

    private func run(root: URL, continuation: AsyncStream<ScanProgress>.Continuation) async {
        filesSeen = 0; physicalBytes = 0; skippedPaths = 0; countedIDs = []

        let topChildren: [BulkEnumerator.Entry]
        do {
            topChildren = try enumerator.enumerate(root)
        } catch {
            continuation.yield(ScanProgress(skippedPaths: 1, currentPath: root.path, children: []))
            continuation.finish()
            return
        }

        var childTotals: [ChildTotal] = []
        for child in topChildren {
            let subtotal = child.isDirectory
                ? sumSubtree(child.node.path, continuation: continuation)
                : accountFile(child.node)
            childTotals.append(ChildTotal(
                name: child.name, url: child.node.path,
                isDirectory: child.isDirectory, physicalTotal: subtotal))
        }

        let final = ScanProgress(
            filesSeen: filesSeen, physicalBytes: physicalBytes,
            skippedPaths: skippedPaths, currentPath: "",
            children: childTotals.sorted { $0.physicalTotal > $1.physicalTotal })
        continuation.yield(final)
        continuation.finish()
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

    private func sumSubtree(_ dir: URL, continuation: AsyncStream<ScanProgress>.Continuation) -> Int64 {
        let entries: [BulkEnumerator.Entry]
        do {
            entries = try enumerator.enumerate(dir)
        } catch {
            skippedPaths += 1
            return 0
        }

        var total: Int64 = 0
        for entry in entries {
            if entry.isDirectory {
                total += sumSubtree(entry.node.path, continuation: continuation)
            } else {
                total += accountFile(entry.node)
            }
        }

        continuation.yield(ScanProgress(
            filesSeen: filesSeen, physicalBytes: physicalBytes,
            skippedPaths: skippedPaths, currentPath: dir.path))
        return total
    }
}
