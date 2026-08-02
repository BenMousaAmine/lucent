//
//  SnapshotInspector.swift
//  Lucent
//
//  Created by Amine ben moussa on 02/06/26.
//

import Darwin
import Foundation

enum SnapshotInspectorError: Error, Equatable {
    case openFailed(path: String, errno: Int32)
    case listFailed(path: String, errno: Int32)
}

struct SnapshotInspector {

    func snapshots(forVolumeAt volumeMount: URL) throws -> [String] {
        let fd = volumeMount.withUnsafeFileSystemRepresentation { rep -> Int32 in
            guard let rep else { return -1 }
            return open(rep, O_RDONLY)
        }
        guard fd >= 0 else {
            throw SnapshotInspectorError.openFailed(path: volumeMount.path, errno: errno)
        }
        defer { close(fd) }

        var attrList = attrlist()
        attrList.bitmapcount = u_short(ATTR_BIT_MAP_COUNT)
        attrList.commonattr = attrgroup_t(ATTR_BULK_REQUIRED)

        let bufSize = 64 * 1024
        var buffer = [UInt8](repeating: 0, count: bufSize)

        let count = buffer.withUnsafeMutableBytes { raw -> Int32 in
            fs_snapshot_list(fd, &attrList, raw.baseAddress, bufSize, 0)
        }
        guard count >= 0 else {
            throw SnapshotInspectorError.listFailed(path: volumeMount.path, errno: errno)
        }
        if count == 0 { return [] }

        return Self.parseSnapshotNames(buffer, entryCount: Int(count))
    }

    private static func parseSnapshotNames(_ buffer: [UInt8], entryCount: Int) -> [String] {
        var names: [String] = []
        buffer.withUnsafeBytes { raw in
            var cursor = 0
            for _ in 0..<entryCount {
                guard cursor + MemoryLayout<UInt32>.size <= raw.count else { break }
                let entryLen = Int(raw.load(fromByteOffset: cursor, as: UInt32.self))
                let base = cursor + MemoryLayout<UInt32>.size

                let attrSetSize = MemoryLayout<attribute_set_t>.size
                let refOffset = base + attrSetSize
                guard refOffset + MemoryLayout<attrreference_t>.size <= raw.count else {
                    cursor += entryLen
                    continue
                }
                let ref = raw.load(fromByteOffset: refOffset, as: attrreference_t.self)
                let nameStart = refOffset + Int(ref.attr_dataoffset)
                let nameLen = Int(ref.attr_length)
                if nameLen > 0, nameStart + nameLen <= raw.count {
                    let bytes = (0..<nameLen - 1).compactMap { i -> UInt8? in
                        raw.load(fromByteOffset: nameStart + i, as: UInt8.self)
                    }
                    if let s = String(bytes: bytes, encoding: .utf8) { names.append(s) }
                }
                cursor += entryLen
            }
        }
        return names
    }
}
