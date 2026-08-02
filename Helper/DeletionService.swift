//
//  DeletionService.swift
//  LucentHelper
//
//  Created by Amine ben moussa on 31/07/26.
//

import Foundation

final class DeletionService: NSObject, DeletionServiceProtocol {

    private let validator = SIPPathValidator()
    private let fileManager = FileManager.default

    func ping(reply: @escaping (Bool) -> Void) {
        reply(true)
    }

    func removePaths(_ paths: [String],
                     strategyRawValues: [String],
                     reply: @escaping (_ removed: [String],
                                       _ refused: [String],
                                       _ reasons: [String]) -> Void) {
        let (allowed, refusedBySIP) = validator.partition(paths)
        let allowedSet = Set(allowed)

        var removed: [String] = []
        var refused: [String] = refusedBySIP
        var reasons: [String] = refusedBySIP.map { _ in "SIP-protected path refused" }

        for (i, path) in paths.enumerated() {
            guard allowedSet.contains(path) else { continue }
            let strategy = strategyRawValues.indices.contains(i) ? strategyRawValues[i] : "trash"
            do {
                try remove(path: path, strategyRawValue: strategy)
                removed.append(path)
            } catch {
                refused.append(path)
                reasons.append((error as NSError).localizedDescription)
            }
        }

        reply(removed, refused, reasons)
    }

    // MARK: - Private

    private func remove(path: String, strategyRawValue: String) throws {
        let url = URL(fileURLWithPath: path)
        try fileManager.removeItem(at: url)
    }
}
