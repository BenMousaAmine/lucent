//
//  DockerProbeTests.swift
//  Lucent
//
//  Created by Amine ben moussa on 21/07/26.
//

import Testing
import Foundation
@testable import Lucent

private struct FakeRunner: DockerCommandRunner {
    var responses: [String: Data] = [:]
    var failInfo = false

    func run(_ args: [String]) throws -> Data {
        if args.first == "info" {
            if failInfo { throw DockerCLIError.dockerNotFound }
            return Data("ok".utf8)
        }
        let key = args.joined(separator: " ")
        guard let data = responses[key] else { throw DockerCLIError.dockerNotFound }
        return data
    }
}

private enum Fixtures {
    static let df = Data("""
    {"Active":"38","Reclaimable":"85.72GB (89%)","Size":"95.72GB","TotalCount":"68","Type":"Images"}
    {"Active":"24","Reclaimable":"60.93MB (53%)","Size":"113.3MB","TotalCount":"43","Type":"Containers"}
    {"Active":"27","Reclaimable":"2.958GB (8%)","Size":"33.65GB","TotalCount":"45","Type":"Local Volumes"}
    {"Active":"0","Reclaimable":"18.53GB","Size":"43.19GB","TotalCount":"304","Type":"Build Cache"}
    """.utf8)

    static let images = Data("""
    {"Containers":"1","ID":"e140daa53de9","Repository":"balancefitlab/api","Size":"445MB","Tag":"local"}
    {"Containers":"0","ID":"6887638afad5","Repository":"old","Size":"94.1MB","Tag":"<none>"}
    """.utf8)

    static let containers = Data("""
    {"ID":"a5b2e968c1fc","Image":"balancefitlab/api:local","Names":"bfl-api","State":"running","Status":"Up 2 days","Size":"1kB (virtual 445MB)"}
    {"ID":"779ec9cb87e4","Image":"old","Names":"old-1","State":"exited","Status":"Exited (0)","Size":"60.93MB (virtual 94.1MB)"}
    """.utf8)

    static let volumes = Data("""
    {"Name":"1ae27c2bdd32","Driver":"local","Labels":"com.docker.volume.anonymous="}
    {"Name":"mydb","Driver":"local","Labels":""}
    """.utf8)

    static let dfVerbose = """
    Images space usage:

    REPOSITORY   TAG   SIZE
    old          <none>   94.1MB

    Local Volumes space usage:

    VOLUME NAME    LINKS     SIZE
    1ae27c2bdd32   0         2.9GB
    mydb           1         58MB

    """

    static func runner() -> FakeRunner {
        FakeRunner(responses: [
            "system df --format json": df,
            "image ls --format json": images,
            "container ls -a --size --format json": containers,
            "volume ls --format json": volumes,
            "system df -v": Data(dfVerbose.utf8),
        ])
    }
}

struct DockerProbeTests {

    @Test("Produces one Finding per dangling image, stopped container, and volume, plus aggregate build cache")
    func perElementFindings() async throws {
        let probe = DockerProbe(runner: Fixtures.runner())
        let findings = try await probe.scan()

        let byKind = Dictionary(grouping: findings, by: { $0.kind })
        #expect(Set(byKind.keys) == ["danglingImage", "buildCache", "stoppedContainer", "volume"])
        #expect(byKind["danglingImage"]?.count == 1)
        #expect(byKind["stoppedContainer"]?.count == 1)
        #expect(byKind["volume"]?.count == 2)
        #expect(byKind["buildCache"]?.count == 1)

        #expect(!(byKind["stoppedContainer"]?.contains { $0.owner == "bfl-api" } ?? false))

        let image = byKind["danglingImage"]!.first!
        #expect(image.owner == "old")
        if case let .freedInContainerOnly(b) = image.reclaimable {
            #expect(b == 94_100_000)
        } else { Issue.record("image reclaimable must be freedInContainerOnly") }

        let container = byKind["stoppedContainer"]!.first!
        #expect(container.owner == "old-1")
        if case let .freedInContainerOnly(b) = container.reclaimable {
            #expect(b == 60_930_000)
        } else { Issue.record("container reclaimable must be freedInContainerOnly") }
    }

    @Test("Volumes use system df -v for real per-volume size, never .safe")
    func volumeSizes() async throws {
        let probe = DockerProbe(runner: Fixtures.runner())
        let findings = try await probe.scan()
        let volumes = findings.filter { $0.kind == "volume" }

        #expect(volumes.allSatisfy { $0.risk == .conditional })
        let anon = volumes.first { $0.owner == "1ae27c2bdd32" }
        if case let .freedInContainerOnly(b) = anon?.reclaimable {
            #expect(b == 2_900_000_000)
        } else { Issue.record("volume reclaimable must be freedInContainerOnly") }
    }

    @Test("Tiering: images safe, build cache safe, containers/volumes conditional")
    func tiering() async throws {
        let probe = DockerProbe(runner: Fixtures.runner())
        let findings = try await probe.scan()

        #expect(findings.filter { $0.kind == "danglingImage" }.allSatisfy { $0.risk == .safe })
        #expect(findings.filter { $0.kind == "buildCache" }.allSatisfy { $0.risk == .safe })
        #expect(findings.filter { $0.kind == "stoppedContainer" }.allSatisfy { $0.risk == .conditional })
        #expect(findings.filter { $0.kind == "volume" }.allSatisfy { $0.risk == .conditional })
    }

    @Test("Degrades gracefully when docker is absent")
    func degrades() async throws {
        let probe = DockerProbe(runner: FakeRunner(failInfo: true))
        #expect(await probe.isAvailable() == false)
    }
}
