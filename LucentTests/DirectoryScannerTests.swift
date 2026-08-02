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

    private func finalProgress(_ root: URL) async -> ScanProgress? {
        var last: ScanProgress?
        for await p in DirectoryScanner().scan(root: root) { last = p }
        return last
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
