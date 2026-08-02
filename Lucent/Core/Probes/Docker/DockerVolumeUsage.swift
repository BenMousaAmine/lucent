//
//  DockerVolumeUsage.swift
//  Lucent
//
//  Created by Amine ben moussa on 21/07/26.
//

import Foundation

struct DockerVolumeUsageRow: Equatable {
    let name: String
    let links: Int
    let size: String
}

enum DockerVolumeUsage {
    static func parse(_ text: String) -> [DockerVolumeUsageRow] {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        guard let headerIndex = lines.firstIndex(where: { $0.hasPrefix("VOLUME NAME") }) else {
            return []
        }
        var rows: [DockerVolumeUsageRow] = []
        for line in lines[(headerIndex + 1)...] {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { break }
            let parts = trimmed.split(separator: " ", omittingEmptySubsequences: true)
            guard parts.count >= 3, let links = Int(parts[parts.count - 2]) else { continue }
            let name = parts[0..<(parts.count - 2)].joined(separator: " ")
            let size = String(parts[parts.count - 1])
            rows.append(DockerVolumeUsageRow(name: name, links: links, size: size))
        }
        return rows
    }
}
