//
//  DeletionServiceProtocol.swift
//  Lucent
//
//  Created by Amine ben moussa on 25/07/26.
//

import Foundation

@objc protocol DeletionServiceProtocol {

    func removePaths(_ paths: [String],
                     strategyRawValues: [String],
                     reply: @escaping (_ removed: [String],
                                       _ refused: [String],
                                       _ reasons: [String]) -> Void)

    func ping(reply: @escaping (Bool) -> Void)
}

enum DeletionWire {
    static func encode(_ plan: DeletionPlan) -> (paths: [String], strategies: [String]) {
        let paths = plan.removals.map { $0.path.path }
        let strategies = plan.removals.map { $0.strategy.rawValue }
        return (paths, strategies)
    }
}
