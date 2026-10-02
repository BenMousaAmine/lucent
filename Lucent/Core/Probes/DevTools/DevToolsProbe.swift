import Foundation

struct DevToolsProbe: DomainProbe {
    let domain: Domain = .devTools
    private let home: URL
    private let minimumReportableSize: Int64
    private let manifest: RuleManifest

    init(home: URL = FileManager.default.homeDirectoryForCurrentUser,
         minimumReportableSize: Int64 = 10 * 1024 * 1024,
         manifest: RuleManifest = .default) {
        self.home = home
        self.minimumReportableSize = minimumReportableSize
        self.manifest = manifest
    }

    func isAvailable() async -> Bool { true }

    func scan() async throws -> [Finding] {
        (crashDumpFindings() + jetBrainsFindings() + ndkFindings() + systemImageFindings() + arduinoFindings())
            .filter { $0.reclaimable.bytes >= minimumReportableSize }
    }

    private func crashDumpFindings() -> [Finding] {
        let nodes = names(in: home)
            .filter { $0.hasSuffix(".hprof") }
            .compactMap { try? PathMeasurer().measure(home.appendingPathComponent($0)) }
        guard !nodes.isEmpty else { return [] }
        let explanation = String(
            localized: "\(nodes.count) memory dumps an IDE (IntelliJ, WebStorm, Android Studio…) wrote in your home folder when it ran out of memory or crashed. Nothing reads them afterwards unless you send one to the IDE's support."
        )
        return [makeFinding(kind: "ideCrashDump", owner: "IDE", nodes: nodes,
                            risk: .safe, reversibility: .trash, explanation: explanation, comesBack: false)]
    }

    private func jetBrainsFindings() -> [Finding] {
        let root = home.appendingPathComponent("Library/Application Support/JetBrains")
        var versions: [String: [(name: String, version: String)]] = [:]
        for name in names(in: root) {
            guard let split = name.firstIndex(where: \.isNumber), split != name.startIndex else { continue }
            let version = String(name[split...])
            guard !Self.versionKey(version).isEmpty else { continue }
            versions[String(name[..<split]), default: []].append((name, version))
        }
        return versions.flatMap { product, installed -> [Finding] in
            let sorted = installed.sorted { Self.versionKey($0.version).lexicographicallyPrecedes(Self.versionKey($1.version)) }
            guard let newest = sorted.last else { return [] }
            return sorted.dropLast().map { old in
                let explanation = String(
                    localized: "Settings, plugins and indexes kept for \(product) \(old.version). You now have \(product) \(newest.version), which copied what it needed the first time it started. Keep this only if you still open the old version."
                )
                return makeFinding(kind: "oldJetBrainsVersion", owner: "\(product) \(old.version)",
                                   nodes: [PathMeasurer().measureDirectory(root.appendingPathComponent(old.name))],
                                   risk: .conditional, reversibility: .trash, explanation: explanation, comesBack: false)
            }
        }
    }

    private func ndkFindings() -> [Finding] {
        let root = home.appendingPathComponent("Library/Android/sdk/ndk")
        let sorted = names(in: root)
            .filter { !Self.versionKey($0).isEmpty }
            .sorted { Self.versionKey($0).lexicographicallyPrecedes(Self.versionKey($1)) }
        guard let newest = sorted.last else { return [] }
        return sorted.dropLast().map { version in
            let explanation = String(
                localized: "An older Android NDK (the native toolchain); the newest one installed is \(newest). A project that asks for exactly version \(version) makes Android Studio download it again."
            )
            return makeFinding(kind: "androidOldNDK", owner: "Android NDK \(version)",
                               nodes: [PathMeasurer().measureDirectory(root.appendingPathComponent(version))],
                               risk: .conditional, reversibility: .regenerable, explanation: explanation, comesBack: false)
        }
    }

    private func systemImageFindings() -> [Finding] {
        let root = home.appendingPathComponent("Library/Android/sdk/system-images")
        let used = usedSystemImages()
        return names(in: root).filter { !$0.hasPrefix(".") && !used.contains($0) }.sorted().map { image in
            let explanation = String(
                localized: "Android emulator system image \(image). None of your emulators uses it. You can download it again from Android Studio's SDK Manager."
            )
            return makeFinding(kind: "androidUnusedSystemImage", owner: image,
                               nodes: [PathMeasurer().measureDirectory(root.appendingPathComponent(image))],
                               risk: .conditional, reversibility: .regenerable, explanation: explanation, comesBack: false)
        }
    }

    private func usedSystemImages() -> Set<String> {
        let avdRoot = home.appendingPathComponent(".android/avd")
        var used: Set<String> = []
        for avd in names(in: avdRoot) where avd.hasSuffix(".avd") {
            let config = avdRoot.appendingPathComponent(avd).appendingPathComponent("config.ini")
            guard let text = try? String(contentsOf: config, encoding: .utf8) else { continue }
            for line in text.split(separator: "\n") where line.hasPrefix("image.sysdir") {
                let parts = line.split(separator: "=").last?.split(separator: "/").map(String.init) ?? []
                if let index = parts.firstIndex(of: "system-images"), parts.count > index + 1 {
                    used.insert(parts[index + 1])
                }
            }
        }
        return used
    }

    private func arduinoFindings() -> [Finding] {
        let staging = home.appendingPathComponent("Library/Arduino15/staging")
        guard FileManager.default.fileExists(atPath: staging.path) else { return [] }
        let explanation = String(
            localized: "Packages the Arduino IDE downloaded while installing boards and libraries. They are already installed; the IDE downloads them again only if you reinstall something."
        )
        return [makeFinding(kind: "arduinoDownloads", owner: "Arduino",
                            nodes: [PathMeasurer().measureDirectory(staging)],
                            risk: .safe, reversibility: .regenerable, explanation: explanation, comesBack: true)]
    }

    private func names(in directory: URL) -> [String] {
        (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
    }

    private static func versionKey(_ version: String) -> [Int] {
        let parts = version.split(separator: ".").map { Int($0) }
        return parts.contains(nil) ? [] : parts.compactMap { $0 }
    }

    private func makeFinding(
        kind: String, owner: String, nodes: [FileNode], risk: RiskTier, reversibility: Reversibility,
        explanation: String, comesBack: Bool
    ) -> Finding {
        let tier = manifest.resolved(domain: .devTools, kind: kind,
                                     fallbackRisk: risk, fallbackReversibility: reversibility)
        return Finding(
            id: UUID(),
            domain: .devTools,
            kind: kind,
            nodes: nodes,
            reclaimable: .returnedToOS(nodes.reduce(0) { $0 + $1.physicalSize }),
            owner: owner,
            state: .stale,
            risk: tier.risk,
            reversibility: tier.reversibility,
            explanation: explanation,
            comesBack: comesBack
        )
    }
}
