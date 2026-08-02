//
//  DockerByteSizeTests.swift
//  Lucent
//
//  Created by Amine ben moussa on 11/06/26.
//

import Testing
@testable import Lucent

struct DockerByteSizeTests {

    @Test("Parses plain unit strings")
    func plainUnits() {
        #expect(DockerByteSize.bytes(from: "445MB") == 445_000_000)
        #expect(DockerByteSize.bytes(from: "2.958GB") == 2_958_000_000)
        #expect(DockerByteSize.bytes(from: "94.1MB") == 94_100_000)
        #expect(DockerByteSize.bytes(from: "0B") == 0)
        #expect(DockerByteSize.bytes(from: "113.3MB") == 113_300_000)
    }

    @Test("Strips trailing parenthetical from system df Reclaimable")
    func withParenthetical() {
        #expect(DockerByteSize.bytes(from: "85.72GB (89%)") == 85_720_000_000)
        #expect(DockerByteSize.bytes(from: "60.93MB (53%)") == 60_930_000)
    }

    @Test("Returns nil for N/A and garbage")
    func unparseable() {
        #expect(DockerByteSize.bytes(from: "N/A") == nil)
        #expect(DockerByteSize.bytes(from: "") == nil)
        #expect(DockerByteSize.bytes(from: "abc") == nil)
    }

    @Test("Bare number is treated as bytes")
    func bareNumber() {
        #expect(DockerByteSize.bytes(from: "1024") == 1024)
    }
}
