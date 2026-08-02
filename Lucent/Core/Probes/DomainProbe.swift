//
//  DomainProbe.swift
//  Lucent
//
//  Created by Amine ben moussa on 02/06/26.
//

import Foundation

protocol DomainProbe {
    var domain: Domain { get }

    func isAvailable() async -> Bool

    func scan() async throws -> [Finding]
}
