//
//  PathMeasurer.swift
//  Lucent
//
//  Created by Amine ben moussa on 02/06/26.
//

import Foundation

enum MeasurementError: Error, Equatable {
    case statFailed(path: String, errno: Int32)
}

struct PathMeasurer {

    private static let blockSize: Int64 = 512

    func measure(_ url: URL) throws -> FileNode {
        var info = stat()
        let result = url.withUnsafeFileSystemRepresentation { rep -> Int32 in
            guard let rep else { return -1 }
            return lstat(rep, &info)
        }

        guard result == 0 else {
            throw MeasurementError.statFailed(path: url.path, errno: errno)
        }

        let logical = Int64(info.st_size)
        let physical = Int64(info.st_blocks) * Self.blockSize

        return FileNode(
            path: url,
            logicalSize: logical,
            physicalSize: physical,
            linkCount: Int(info.st_nlink)
        )
    }

    func measureDirectory(_ url: URL) -> FileNode {
        var total: Int64 = 0
        if let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.totalFileAllocatedSizeKey]) {
            for case let file as URL in enumerator {
                total += Int64((try? file.resourceValues(forKeys: [.totalFileAllocatedSizeKey]))?.totalFileAllocatedSize ?? 0)
            }
        }
        return FileNode(path: url, logicalSize: total, physicalSize: total, linkCount: 1)
    }
}
