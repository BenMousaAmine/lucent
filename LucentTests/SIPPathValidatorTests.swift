//
//  SIPPathValidatorTests.swift
//  Lucent
//
//  Created by Amine ben moussa on 25/07/26.
//

import Testing
import Foundation
@testable import Lucent

struct SIPPathValidatorTests {

    private let validator = SIPPathValidator()

    @Test("Protected system roots are refused")
    func protectedRootsRefused() {
        #expect(validator.isProtected("/System"))
        #expect(validator.isProtected("/System/Library/CoreServices/Finder.app"))
        #expect(validator.isProtected("/bin/ls"))
        #expect(validator.isProtected("/usr/lib/libSystem.dylib"))
        #expect(validator.isProtected("/private/var/db/anything"))
    }

    @Test("Trailing slash does not sneak a protected path past the check")
    func trailingSlashNormalized() {
        #expect(validator.isProtected("/System/"))
    }

    @Test("User-owned and app paths are allowed")
    func userPathsAllowed() {
        #expect(!validator.isProtected("/Users/amine/Library/Caches/npm"))
        #expect(!validator.isProtected("/Users/amine/Developer/proj/node_modules"))
        #expect(!validator.isProtected("/Volumes/LucentTest-1234/cache.bin"))
    }

    @Test("/usr/local is a carve-out even though /usr is protected")
    func usrLocalException() {
        #expect(!validator.isProtected("/usr/local"))
        #expect(!validator.isProtected("/usr/local/bin/brew"))
        #expect(validator.isProtected("/usr/bin/swift"))
    }

    @Test("A prefix that is not a path boundary is NOT treated as protected")
    func noFalsePrefixMatch() {
        #expect(!validator.isProtected("/Systemic/data"))
        #expect(!validator.isProtected("/usr-backup/file"))
    }

    @Test("Partition splits allowed from refused without dropping any")
    func partitionSplits() {
        let (allowed, refused) = validator.partition([
            "/Users/amine/Library/Caches/x",
            "/System/Library/y",
            "/usr/local/bin/z",
            "/bin/sh",
        ])
        #expect(allowed == ["/Users/amine/Library/Caches/x", "/usr/local/bin/z"])
        #expect(refused == ["/System/Library/y", "/bin/sh"])
    }
}

struct DeletionWireTests {

    @Test("Encoding a plan yields parallel path/strategy arrays in order")
    func encodePreservesOrder() {
        let plan = DeletionPlan(removals: [
            PlannedRemoval(path: URL(fileURLWithPath: "/a/one"), strategy: .trash,
                           physicalSize: 1, reclaimable: .returnedToOS(1)),
            PlannedRemoval(path: URL(fileURLWithPath: "/a/two"), strategy: .quarantine,
                           physicalSize: 2, reclaimable: .returnedToOS(2)),
        ])
        let wire = DeletionWire.encode(plan)
        #expect(wire.paths == ["/a/one", "/a/two"])
        #expect(wire.strategies == ["trash", "quarantine"])
    }
}
