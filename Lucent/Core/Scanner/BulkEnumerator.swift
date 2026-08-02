//
//  BulkEnumerator.swift
//  Lucent
//
//  Created by Amine ben moussa on 08/06/26.
//

import Darwin
import Foundation

enum BulkEnumeratorError: Error, Equatable {
    case openFailed(path: String, errno: Int32)
    case enumerateFailed(path: String, errno: Int32)
}

struct BulkEnumerator {

    struct Entry {
        let name: String
        let isDirectory: Bool
        let node: FileNode
    }

    private static func makeAttrList() -> attrlist {
        var al = attrlist()
        al.bitmapcount = u_short(ATTR_BIT_MAP_COUNT)
        al.commonattr = attrgroup_t(ATTR_CMN_RETURNED_ATTRS)
            | attrgroup_t(ATTR_CMN_NAME)
            | attrgroup_t(ATTR_CMN_OBJTYPE)
            | attrgroup_t(ATTR_CMN_FILEID)
        al.fileattr = attrgroup_t(ATTR_FILE_DATALENGTH) | attrgroup_t(ATTR_FILE_ALLOCSIZE)
        return al
    }

    func enumerate(_ directory: URL) throws -> [Entry] {
        let fd = directory.withUnsafeFileSystemRepresentation { rep -> Int32 in
            guard let rep else { return -1 }
            return open(rep, O_RDONLY)
        }
        guard fd >= 0 else {
            throw BulkEnumeratorError.openFailed(path: directory.path, errno: errno)
        }
        defer { close(fd) }

        var attrList = Self.makeAttrList()
        var entries: [Entry] = []
        let bufSize = 256 * 1024
        var buffer = [UInt8](repeating: 0, count: bufSize)

        while true {
            let retcount = buffer.withUnsafeMutableBytes { raw -> Int32 in
                getattrlistbulk(fd, &attrList, raw.baseAddress, bufSize, 0)
            }
            if retcount == -1 {
                throw BulkEnumeratorError.enumerateFailed(path: directory.path, errno: errno)
            }
            if retcount == 0 { break }

            buffer.withUnsafeBytes { raw in
                var offset = 0
                for _ in 0..<Int(retcount) {
                    if let entry = Self.decodeEntry(raw, at: offset, parent: directory) {
                        entries.append(entry.entry)
                        offset += entry.length
                    } else {
                        break
                    }
                }
            }
        }
        return entries
    }

    private static func decodeEntry(
        _ raw: UnsafeRawBufferPointer, at offset: Int, parent: URL
    ) -> (entry: Entry, length: Int)? {
        var cursor = offset
        guard cursor + MemoryLayout<UInt32>.size <= raw.count else { return nil }
        let entryLength = Int(raw.load(fromByteOffset: cursor, as: UInt32.self))
        cursor += MemoryLayout<UInt32>.size

        guard cursor + MemoryLayout<attribute_set_t>.size <= raw.count else { return nil }
        let returned = raw.loadUnaligned(fromByteOffset: cursor, as: attribute_set_t.self)
        cursor += MemoryLayout<attribute_set_t>.size

        var name = ""
        if returned.commonattr & attrgroup_t(ATTR_CMN_NAME) != 0 {
            let refOffset = cursor
            let ref = raw.loadUnaligned(fromByteOffset: refOffset, as: attrreference_t.self)
            let nameStart = refOffset + Int(ref.attr_dataoffset)
            let nameLen = Int(ref.attr_length)
            if nameLen > 0, nameStart + nameLen <= raw.count {
                let bytes = (0..<nameLen - 1).map { raw.load(fromByteOffset: nameStart + $0, as: UInt8.self) }
                name = String(decoding: bytes, as: UTF8.self)
            }
            cursor += MemoryLayout<attrreference_t>.size
        }

        var isDir = false
        if returned.commonattr & attrgroup_t(ATTR_CMN_OBJTYPE) != 0 {
            let objType = raw.loadUnaligned(fromByteOffset: cursor, as: fsobj_type_t.self)
            isDir = (objType == fsobj_type_t(VDIR.rawValue))
            cursor += MemoryLayout<fsobj_type_t>.size
        }

        var fileID: UInt64 = 0
        if returned.commonattr & attrgroup_t(ATTR_CMN_FILEID) != 0 {
            fileID = raw.loadUnaligned(fromByteOffset: cursor, as: UInt64.self)
            cursor += MemoryLayout<UInt64>.size
        }

        var physical: Int64 = 0
        if returned.fileattr & attrgroup_t(ATTR_FILE_ALLOCSIZE) != 0 {
            physical = Int64(raw.loadUnaligned(fromByteOffset: cursor, as: off_t.self))
            cursor += MemoryLayout<off_t>.size
        }

        var logical: Int64 = 0
        if returned.fileattr & attrgroup_t(ATTR_FILE_DATALENGTH) != 0 {
            logical = Int64(raw.loadUnaligned(fromByteOffset: cursor, as: off_t.self))
            cursor += MemoryLayout<off_t>.size
        }

        let node = FileNode(
            path: parent.appendingPathComponent(name),
            logicalSize: logical,
            physicalSize: physical,
            linkCount: 1,
            fileID: fileID
        )
        return (Entry(name: name, isDirectory: isDir, node: node), entryLength)
    }
}
