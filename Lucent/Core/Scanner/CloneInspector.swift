//
//  CloneInspector.swift
//  Lucent
//
//  Created by Amine ben moussa on 02/06/26.
//

import Darwin
import Foundation

enum CloneInspectorError: Error, Equatable {
    case openFailed(path: String, errno: Int32)
    case log2physFailed(path: String, errno: Int32)
}

struct CloneInspector {

    func firstPhysicalOffset(_ url: URL) throws -> off_t? {
        let fd = url.withUnsafeFileSystemRepresentation { rep -> Int32 in
            guard let rep else { return -1 }
            return open(rep, O_RDONLY)
        }
        guard fd >= 0 else {
            throw CloneInspectorError.openFailed(path: url.path, errno: errno)
        }
        defer { close(fd) }

        var lp = log2phys()
        lp.l2p_devoffset = 0
        lp.l2p_contigbytes = 0

        let rc = fcntl(fd, F_LOG2PHYS_EXT, &lp)
        guard rc == 0 else {
            if errno == ERANGE { return nil }
            throw CloneInspectorError.log2physFailed(path: url.path, errno: errno)
        }
        return lp.l2p_devoffset
    }

    func sharesExtents(_ a: URL, _ b: URL) throws -> Bool {
        guard
            let pa = try firstPhysicalOffset(a),
            let pb = try firstPhysicalOffset(b)
        else { return false }
        return pa == pb
    }
}
