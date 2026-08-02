//
//  SIPPathValidator.swift
//  Lucent
//
//  Created by Amine ben moussa on 25/07/26.
//

import Foundation

struct SIPPathValidator {

    static let protectedRoots: [String] = [
        "/System",
        "/bin",
        "/sbin",
        "/usr",
        "/private/var/db",
        "/private/var/vm",
        "/Library/Apple",
        "/Applications/Safari.app",
    ]

    static let allowedExceptions: [String] = [
        "/usr/local",
    ]

    let protectedRoots: [String]
    let allowedExceptions: [String]

    init(protectedRoots: [String] = SIPPathValidator.protectedRoots,
         allowedExceptions: [String] = SIPPathValidator.allowedExceptions) {
        self.protectedRoots = protectedRoots
        self.allowedExceptions = allowedExceptions
    }

    func isProtected(_ path: String) -> Bool {
        let normalized = Self.normalize(path)
        if allowedExceptions.contains(where: { normalized.hasPrefix(Self.normalize($0) + "/") || normalized == Self.normalize($0) }) {
            return false
        }
        return protectedRoots.contains { root in
            let r = Self.normalize(root)
            return normalized == r || normalized.hasPrefix(r + "/")
        }
    }

    func partition(_ paths: [String]) -> (allowed: [String], refused: [String]) {
        var allowed: [String] = []
        var refused: [String] = []
        for path in paths {
            if isProtected(path) { refused.append(path) } else { allowed.append(path) }
        }
        return (allowed, refused)
    }

    private static func normalize(_ path: String) -> String {
        guard path.count > 1, path.hasSuffix("/") else { return path }
        return String(path.dropLast())
    }
}
