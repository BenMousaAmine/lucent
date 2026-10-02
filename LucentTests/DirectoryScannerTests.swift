//
//  DirectoryScannerTests.swift
//  Lucent
//
//  Created by Amine ben moussa on 08/06/26.
//

import Testing
import Foundation
@testable import Lucent

struct DirectoryScannerTests {

    private func finalProgress(_ root: URL, scanner: DirectoryScanner = DirectoryScanner()) async -> ScanProgress? {
        var last: ScanProgress?
        for await p in scanner.scan(root: root) { last = p }
        return last
    }

    @Test("Large subtrees keep their children for drill-down, small ones are pruned")
    func retainsLargeSubtrees() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("LucentTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let bigdir = dir.appendingPathComponent("bigdir")
        let nested = bigdir.appendingPathComponent("nested")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try Data(repeating: 1, count: 100_000).write(to: bigdir.appendingPathComponent("x.bin"))
        try Data(repeating: 2, count: 100_000).write(to: nested.appendingPathComponent("y.bin"))

        let final = await finalProgress(dir, scanner: DirectoryScanner(retainThreshold: 150_000))
        let top = try #require(final?.children?.first)
        let kept = try #require(top.children)

        #expect(top.name == "bigdir")
        #expect(Set(kept.map(\.name)) == ["x.bin", "nested"])
        let nestedNode = try #require(kept.first { $0.name == "nested" })
        #expect(nestedNode.physicalTotal >= 100_000)
        #expect(nestedNode.children == nil)
    }

    @Test("A mount point inside the tree is listed but never entered or counted")
    func skipsMountPoints() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("LucentTests-\(UUID().uuidString)", isDirectory: true)
        let mounted = dir.appendingPathComponent("mounted")
        let local = dir.appendingPathComponent("local")
        try FileManager.default.createDirectory(at: mounted, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: local, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        try Data(repeating: 1, count: 300_000).write(to: mounted.appendingPathComponent("other-disk.bin"))
        try Data(repeating: 2, count: 100_000).write(to: local.appendingPathComponent("mine.bin"))

        let scanner = DirectoryScanner(mountPoints: [mounted.path])
        let final = await finalProgress(dir, scanner: scanner)
        let children = try #require(final?.children)

        #expect(children.first { $0.name == "mounted" }?.physicalTotal == 0)
        #expect((children.first { $0.name == "local" }?.physicalTotal ?? 0) >= 100_000)
        #expect(final?.filesSeen == 1)
        #expect((final?.physicalBytes ?? 0) < 300_000)
    }

    @Test("Per-child totals are correct and sorted by size")
    func perChildTotals() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("LucentTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let bigdir = dir.appendingPathComponent("bigdir")
        let nested = bigdir.appendingPathComponent("nested")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try Data(repeating: 1, count: 100_000).write(to: bigdir.appendingPathComponent("x.bin"))
        try Data(repeating: 2, count: 100_000).write(to: nested.appendingPathComponent("y.bin"))
        try Data(repeating: 3, count: 10_000).write(to: dir.appendingPathComponent("small.bin"))

        let final = await finalProgress(dir)
        let children = try #require(final?.children)

        #expect(children.count == 2)
        #expect(children.first?.name == "bigdir")
        #expect(children.first?.isDirectory == true)
        #expect(children.first!.physicalTotal >= 200_000)
        #expect(children.last?.name == "small.bin")
        #expect(children.last!.physicalTotal < children.first!.physicalTotal)

        #expect(final?.filesSeen == 3)
    }

    @Test("Hard-linked file is counted once, not doubled")
    func dedupHardLink() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("LucentTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let original = dir.appendingPathComponent("original.bin")
        let link = dir.appendingPathComponent("link.bin")
        try Data(repeating: 7, count: 500_000).write(to: original)
        let rc = original.withUnsafeFileSystemRepresentation { o in
            link.withUnsafeFileSystemRepresentation { l -> Int32 in
                guard let o, let l else { return -1 }
                return Foundation.link(o, l)
            }
        }
        #expect(rc == 0)

        let final = await finalProgress(dir)
        let total = try #require(final?.physicalBytes)
        #expect(total < 800_000, "hard link double-counted: \(total)")
        #expect(total >= 500_000)
    }
}
