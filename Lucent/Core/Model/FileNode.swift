//
//  FileNode.swift
//  Lucent
//
//  Created by Amine ben moussa on 21/07/26.
//

import Foundation

struct FileNode: Hashable {
    let path: URL

    let logicalSize: Int64

    let physicalSize: Int64

    let linkCount: Int

    var fileID: UInt64 = 0

    var isSparse: Bool { physicalSize < logicalSize }

    var isClone: Bool = false

    var isReferencedBySnapshot: Bool = false
}
