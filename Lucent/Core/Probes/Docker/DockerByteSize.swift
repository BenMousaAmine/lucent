//
//  DockerByteSize.swift
//  Lucent
//
//  Created by Amine ben moussa on 11/06/26.
//

import Foundation

enum DockerByteSize {

    private static let multipliers: [(suffix: String, factor: Double)] = [
        ("TB", 1e12), ("GB", 1e9), ("MB", 1e6), ("kB", 1e3), ("KB", 1e3), ("B", 1),
    ]

    static func bytes(from raw: String) -> Int64? {
        var s = raw
        if let paren = s.firstIndex(of: "(") {
            s = String(s[..<paren])
        }
        s = s.trimmingCharacters(in: .whitespaces)
        guard !s.isEmpty, s != "N/A" else { return nil }

        for (suffix, factor) in multipliers where s.hasSuffix(suffix) {
            let numberPart = s.dropLast(suffix.count).trimmingCharacters(in: .whitespaces)
            guard let value = Double(numberPart) else { return nil }
            return Int64((value * factor).rounded())
        }
        return Double(s).map { Int64($0.rounded()) }
    }
}
