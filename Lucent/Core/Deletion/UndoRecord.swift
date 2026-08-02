//
//  UndoRecord.swift
//  Lucent
//
//  Created by Amine ben moussa on 24/07/26.
//

import Foundation

struct UndoRecord: Codable, Hashable {
    let originalPath: String
    let currentPath: String
    let strategy: DeletionStrategy
    let physicalSize: Int64
    let timestamp: Date

    init(originalPath: String, currentPath: String, strategy: DeletionStrategy,
         physicalSize: Int64, timestamp: Date = Date()) {
        self.originalPath = originalPath
        self.currentPath = currentPath
        self.strategy = strategy
        self.physicalSize = physicalSize
        self.timestamp = timestamp
    }
}
