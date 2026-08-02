//
//  RuleManifest.swift
//  Lucent
//
//  Created by Amine ben moussa on 31/07/26.
//

import Foundation

struct TieringRule: Codable, Hashable {
    let risk: RiskTier
    let reversibility: Reversibility
}

struct RuleManifest: Codable, Hashable {
    let version: Int
    let rules: [String: [String: TieringRule]]

    func rule(for domain: Domain, kind: String) -> TieringRule? {
        rules[domain.rawValue]?[kind]
    }

    func resolved(domain: Domain, kind: String,
                  fallbackRisk: RiskTier,
                  fallbackReversibility: Reversibility) -> (risk: RiskTier, reversibility: Reversibility) {
        let rule = self.rule(for: domain, kind: kind)
        return (rule?.risk ?? fallbackRisk, rule?.reversibility ?? fallbackReversibility)
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey { case version, rules }

    // MARK: - Loading

    static func load(from data: Data) throws -> RuleManifest {
        try JSONDecoder().decode(RuleManifest.self, from: data)
    }

    func encoded() throws -> Data {
        try JSONEncoder().encode(self)
    }
}

extension RiskTier: Codable {}
extension Reversibility: Codable {}
