//
//  ScanResultRow.swift
//  Lucent
//
//  Created by Amine ben moussa on 02/06/26.
//

import Foundation

struct ScanResultRow: Identifiable {
    let id = UUID()
    let name: String
    let physical: Int64
    let logical: Int64
    let isSparse: Bool
    let linkCount: Int

    init(node: FileNode) {
        self.name = node.path.lastPathComponent
        self.physical = node.physicalSize
        self.logical = node.logicalSize
        self.isSparse = node.isSparse
        self.linkCount = node.linkCount
    }

    var physicalText: String { ByteCountFormatter.string(fromByteCount: physical, countStyle: .file) }
    var logicalText: String { ByteCountFormatter.string(fromByteCount: logical, countStyle: .file) }

    var note: String {
        var parts: [String] = []
        if isSparse { parts.append("sparse (logical ≫ physical)") }
        if linkCount > 1 { parts.append("hard-linked ×\(linkCount): deleting frees nothing") }
        return parts.joined(separator: " · ")
    }
}
