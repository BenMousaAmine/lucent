//
//  CloneInspectorTests.swift
//  Lucent
//
//  Created by Amine ben moussa on 02/06/26.
//

import Testing
import Foundation
import Darwin
@testable import Lucent

struct CloneInspectorTests {

    private func withTempDir(_ body: (URL) throws -> Void) throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("LucentTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        try body(dir)
    }

    @Test("APFS clone: cloned file shares extents with the original")
    func cloneSharesExtents() throws {
        try withTempDir { dir in
            let original = dir.appendingPathComponent("original.bin")
            let clone = dir.appendingPathComponent("clone.bin")
            try Data(repeating: 0xEE, count: 1024 * 1024).write(to: original)

            let rc = original.withUnsafeFileSystemRepresentation { origRep in
                clone.withUnsafeFileSystemRepresentation { cloneRep -> Int32 in
                    guard let origRep, let cloneRep else { return -1 }
                    return clonefile(origRep, cloneRep, 0)
                }
            }
            try #require(rc == 0)

            let inspector = CloneInspector()
            #expect(try inspector.sharesExtents(original, clone) == true)
        }
    }

    @Test("Distinct files do not share extents")
    func distinctFilesDoNotShare() throws {
        try withTempDir { dir in
            let a = dir.appendingPathComponent("a.bin")
            let b = dir.appendingPathComponent("b.bin")
            try Data(repeating: 0x11, count: 1024 * 1024).write(to: a)
            try Data(repeating: 0x22, count: 1024 * 1024).write(to: b)

            let inspector = CloneInspector()
            #expect(try inspector.sharesExtents(a, b) == false)
        }
    }
}
