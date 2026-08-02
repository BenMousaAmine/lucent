//
//  UndoLogTests.swift
//  Lucent
//
//  Created by Amine ben moussa on 24/07/26.
//

import Testing
import Foundation
@testable import Lucent

private struct TempLog {
    let log: UndoLog
    private let dir: URL

    init() {
        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("LucentUndoTest-\(UUID().uuidString.prefix(8))")
        log = UndoLog(url: dir.appendingPathComponent("undo-log.jsonl"))
    }
    func cleanup() { try? FileManager.default.removeItem(at: dir) }

    static func record(_ name: String, strategy: DeletionStrategy = .trash) -> UndoRecord {
        UndoRecord(originalPath: "/orig/\(name)", currentPath: "/trash/\(name)",
                   strategy: strategy, physicalSize: 1_000,
                   timestamp: Date(timeIntervalSince1970: 0))
    }
}

struct UndoLogTests {

    @Test("Appends and reads back records in write order")
    func appendReadOrder() throws {
        let t = TempLog(); defer { t.cleanup() }
        try t.log.append(TempLog.record("a"))
        try t.log.append(TempLog.record("b", strategy: .quarantine))
        try t.log.append(TempLog.record("c"))

        let all = try t.log.readAll()
        #expect(all.map { $0.originalPath } == ["/orig/a", "/orig/b", "/orig/c"])
        #expect(all[1].strategy == .quarantine)
    }

    @Test("A corrupt line is skipped, the rest still read")
    func corruptLineSkipped() throws {
        let t = TempLog(); defer { t.cleanup() }
        try t.log.append(TempLog.record("good1"))
        let handle = try FileHandle(forWritingTo: t.log.url)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data("{ not valid json\n".utf8))
        try handle.close()
        try t.log.append(TempLog.record("good2"))

        let all = try t.log.readAll()
        #expect(all.map { $0.originalPath } == ["/orig/good1", "/orig/good2"])
    }

    @Test("Codable round-trips a record faithfully")
    func codableRoundTrip() throws {
        let t = TempLog(); defer { t.cleanup() }
        let original = TempLog.record("x", strategy: .quarantine)
        try t.log.append(original)
        let read = try t.log.readAll()
        #expect(read.count == 1)
        #expect(read.first == original)
    }

    @Test("Reading a missing log yields empty, not an error")
    func missingLogEmpty() throws {
        let t = TempLog(); defer { t.cleanup() }
        #expect(try t.log.readAll().isEmpty)
    }
}
