import Testing
import Foundation
@testable import Lucent

private enum DevFixture {
    static func makeHome() throws -> URL {
        let fm = FileManager.default
        let home = fm.temporaryDirectory.appendingPathComponent("LucentTests-\(UUID().uuidString)", isDirectory: true)
        func write(_ path: String, _ size: Int) throws {
            let url = home.appendingPathComponent(path)
            try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data(repeating: 9, count: size).write(to: url)
        }
        try write("java_error_in_webstorm.hprof", 80_000)
        try write("notes.txt", 80_000)

        let jetBrains = "Library/Application Support/JetBrains/"
        try write(jetBrains + "WebStorm2025.1/options/a.xml", 50_000)
        try write(jetBrains + "WebStorm2025.2/options/a.xml", 50_000)
        try write(jetBrains + "WebStorm2026.1/options/a.xml", 50_000)
        try write(jetBrains + "IntelliJIdea2025.3/options/a.xml", 50_000)
        try write(jetBrains + "Daemon/log.txt", 50_000)

        try write("Library/Android/sdk/ndk/26.1.10909125/toolchain", 60_000)
        try write("Library/Android/sdk/ndk/29.0.14206865/toolchain", 60_000)
        try write("Library/Android/sdk/system-images/android-36/img", 70_000)
        try write("Library/Android/sdk/system-images/android-37.1/img", 70_000)
        let config = home.appendingPathComponent(".android/avd/Pixel_9_Pro.avd/config.ini")
        try fm.createDirectory(at: config.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("hw.ramSize=2048\nimage.sysdir.1=system-images/android-37.1/google_apis/arm64-v8a/\n".utf8).write(to: config)

        try write("Library/Arduino15/staging/packages/core.zip", 40_000)
        return home
    }
}

struct DevToolsProbeTests {

    private func scan() async throws -> ([Finding], URL) {
        let home = try DevFixture.makeHome()
        return (try await DevToolsProbe(home: home, minimumReportableSize: 10_000).scan(), home)
    }

    @Test("IDE crash dumps in the home folder are one safe item; other files are ignored")
    func crashDumps() async throws {
        let (findings, home) = try await scan()
        defer { try? FileManager.default.removeItem(at: home) }

        let dumps = try #require(findings.first { $0.kind == "ideCrashDump" })
        #expect(dumps.nodes.map(\.path.lastPathComponent) == ["java_error_in_webstorm.hprof"])
        #expect(dumps.risk == .safe)
        #expect(dumps.domain == .devTools)
    }

    @Test("Only superseded JetBrains versions are reported; the newest of each product stays")
    func oldJetBrainsVersions() async throws {
        let (findings, home) = try await scan()
        defer { try? FileManager.default.removeItem(at: home) }

        let old = findings.filter { $0.kind == "oldJetBrainsVersion" }
        #expect(Set(old.compactMap(\.owner)) == ["WebStorm 2025.1", "WebStorm 2025.2"])
        #expect(old.allSatisfy { $0.risk == .conditional })
    }

    @Test("Android: older NDKs and emulator images no emulator uses")
    func android() async throws {
        let (findings, home) = try await scan()
        defer { try? FileManager.default.removeItem(at: home) }

        #expect(findings.filter { $0.kind == "androidOldNDK" }.map(\.owner) == ["Android NDK 26.1.10909125"])
        #expect(findings.filter { $0.kind == "androidUnusedSystemImage" }.map(\.owner) == ["android-36"])
    }

    @Test("Arduino download folder is a safe, regenerable item")
    func arduino() async throws {
        let (findings, home) = try await scan()
        defer { try? FileManager.default.removeItem(at: home) }

        let arduino = try #require(findings.first { $0.kind == "arduinoDownloads" })
        #expect(arduino.nodes.first?.path.lastPathComponent == "staging")
        #expect(arduino.reversibility == .regenerable)
    }
}
