//
//  DisposableAPFSVolumeTests.swift
//  Lucent
//
//  Created by Amine ben moussa on 02/06/26.
//

import Testing
import Foundation
@testable import Lucent

struct DisposableAPFSVolumeTests {

    @Test("Disposable APFS volume mounts, is writable, and tears down clean")
    func mountWriteUnmount() throws {
        let volume = try DisposableAPFSVolume()
        var mountPath = volume.mountPoint.path

        do {
            #expect(FileManager.default.fileExists(atPath: mountPath))

            let file = volume.mountPoint.appendingPathComponent("probe.txt")
            try Data("hello".utf8).write(to: file)
            #expect(FileManager.default.fileExists(atPath: file.path))

            let clone = volume.mountPoint.appendingPathComponent("probe-clone.txt")
            let rc = file.withUnsafeFileSystemRepresentation { src in
                clone.withUnsafeFileSystemRepresentation { dst -> Int32 in
                    guard let src, let dst else { return -1 }
                    return clonefile(src, dst, 0)
                }
            }
            #expect(rc == 0)
        }

        volume.destroy()

        #expect(FileManager.default.fileExists(atPath: mountPath) == false)
        _ = mountPath
    }
}
