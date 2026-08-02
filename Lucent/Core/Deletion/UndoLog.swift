//
//  UndoLog.swift
//  Lucent
//
//  Created by Amine ben moussa on 25/07/26.
//

import Foundation

struct UndoLog {
    let url: URL

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    func append(_ record: UndoRecord) throws {
        let data = try Self.encoder.encode(record)
        var line = data
        line.append(0x0A)

        let fm = FileManager.default
        if !fm.fileExists(atPath: url.path) {
            try fm.createDirectory(at: url.deletingLastPathComponent(),
                                   withIntermediateDirectories: true)
            try line.write(to: url, options: .atomic)
            return
        }
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: line)
    }

    func readAll() throws -> [UndoRecord] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        let content = try String(contentsOf: url, encoding: .utf8)
        return content
            .split(separator: "\n", omittingEmptySubsequences: true)
            .compactMap { line in
                try? Self.decoder.decode(UndoRecord.self, from: Data(line.utf8))
            }
    }

    func remove(_ records: [UndoRecord]) throws {
        let drop = Set(records.map { $0.currentPath })
        let kept = try readAll().filter { !drop.contains($0.currentPath) }
        let body = try kept.map { try Self.encoder.encode($0) }
        var out = Data()
        for line in body { out.append(line); out.append(0x0A) }
        try out.write(to: url, options: .atomic)
    }
}
