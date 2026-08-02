//
//  BulkEnumeratorTests.swift
//  Lucent
//
//  Created by Amine ben moussa on 03/06/26.
//

import Testing
import Foundation
@testable import Lucent

struct BulkEnumeratorTests {

    private func withTempDir(_ body: (URL) throws -> Void) throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("LucentTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        try body(dir)
    }

    @Test("Enumerator finds all entries and matches PathMeasurer per entry")
    func matchesPathMeasurer() throws {
        try withTempDir { dir in
            try Data(repeating: 0x01, count: 4096).write(to: dir.appendingPathComponent("a.bin"))
            try Data(repeating: 0x02, count: 200_000).write(to: dir.appendingPathComponent("b.bin"))
            try FileManager.default.createDirectory(
                at: dir.appendingPathComponent("sub"), withIntermediateDirectories: true)

            let entries = try BulkEnumerator().enumerate(dir)
            let byName = Dictionary(uniqueKeysWithValues: entries.map { ($0.name, $0) })

            #expect(Set(byName.keys) == ["a.bin", "b.bin", "sub"])
            #expect(byName["sub"]?.isDirectory == true)
            #expect(byName["a.bin"]?.isDirectory == false)

            let measurer = PathMeasurer()
            for (name, entry) in byName where name != "sub" {
                let viaStat = try measurer.measure(dir.appendingPathComponent(name))
                #expect(entry.node.logicalSize == viaStat.logicalSize, "logical mismatch for \(name)")
                #expect(entry.node.physicalSize == viaStat.physicalSize, "physical mismatch for \(name)")
            }
        }
    }

    @Test("Sparse file: bulk enumerator reports physical < logical")
    func sparseViaBulk() throws {
        try withTempDir { dir in
            let url = dir.appendingPathComponent("sparse.bin")
            let logicalEnd: off_t = 32 * 1024 * 1024
            FileManager.default.createFile(atPath: url.path, contents: nil)
            let h = try FileHandle(forWritingTo: url)
            try h.seek(toOffset: UInt64(logicalEnd - 1))
            h.write(Data([0]))
            try h.synchronize()
            try h.close()

            let entries = try BulkEnumerator().enumerate(dir)
            let sparse = try #require(entries.first { $0.name == "sparse.bin" })
            #expect(sparse.node.logicalSize == Int64(logicalEnd))
            #expect(sparse.node.physicalSize < sparse.node.logicalSize)
        }
    }

    @Test("Opening a non-directory path throws")
    func openFailure() throws {
        try withTempDir { dir in
            let missing = dir.appendingPathComponent("nope")
            #expect(throws: BulkEnumeratorError.self) {
                _ = try BulkEnumerator().enumerate(missing)
            }
        }
    }
}
