//
//  PathMeasurerTests.swift
//  Lucent
//
//  Created by Amine ben moussa on 02/06/26.
//

import Testing
import Foundation
@testable import Lucent

struct PathMeasurerTests {

    private func withTempDir(_ body: (URL) throws -> Void) throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("LucentTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        try body(dir)
    }

    @Test("Plain file: physical >= logical, both reflect the written bytes")
    func plainFile() throws {
        try withTempDir { dir in
            let url = dir.appendingPathComponent("plain.bin")
            let payload = Data(repeating: 0xAB, count: 8192)
            try payload.write(to: url)

            let node = try PathMeasurer().measure(url)

            #expect(node.logicalSize == 8192)
            #expect(node.physicalSize >= node.logicalSize)
            #expect(node.isSparse == false)
            #expect(node.linkCount == 1)
        }
    }

    @Test("Sparse file: logical huge, physical tiny → isSparse true")
    func sparseFile() throws {
        try withTempDir { dir in
            let url = dir.appendingPathComponent("sparse.bin")

            let logicalEnd: off_t = 64 * 1024 * 1024
            let handle = try FileHandle(forWritingTo: createEmptyFile(at: url))
            defer { try? handle.close() }
            try handle.seek(toOffset: UInt64(logicalEnd - 1))
            handle.write(Data([0x00]))
            try handle.synchronize()

            let node = try PathMeasurer().measure(url)

            #expect(node.logicalSize == Int64(logicalEnd))
            #expect(node.physicalSize < node.logicalSize)
            #expect(node.physicalSize < 1024 * 1024)
            #expect(node.isSparse == true)
        }
    }

    @Test("Hard link: both paths report linkCount == 2")
    func hardLink() throws {
        try withTempDir { dir in
            let original = dir.appendingPathComponent("original.bin")
            let link = dir.appendingPathComponent("link.bin")
            try Data(repeating: 0xCD, count: 4096).write(to: original)

            let rc = original.withUnsafeFileSystemRepresentation { origRep in
                link.withUnsafeFileSystemRepresentation { linkRep -> Int32 in
                    guard let origRep, let linkRep else { return -1 }
                    return Foundation.link(origRep, linkRep)
                }
            }
            #expect(rc == 0)

            let a = try PathMeasurer().measure(original)
            let b = try PathMeasurer().measure(link)

            #expect(a.linkCount == 2)
            #expect(b.linkCount == 2)
            #expect(a.physicalSize == b.physicalSize)
        }
    }

    @Test("Missing path throws statFailed")
    func missingPath() throws {
        try withTempDir { dir in
            let url = dir.appendingPathComponent("does-not-exist")
            #expect(throws: MeasurementError.self) {
                _ = try PathMeasurer().measure(url)
            }
        }
    }

    private func createEmptyFile(at url: URL) throws -> URL {
        guard FileManager.default.createFile(atPath: url.path, contents: nil) else {
            throw MeasurementError.statFailed(path: url.path, errno: errno)
        }
        return url
    }
}
