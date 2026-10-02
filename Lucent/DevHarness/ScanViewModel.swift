//
//  ScanViewModel.swift
//  Lucent
//
//  Created by Amine ben moussa on 11/06/26.
//

import Foundation
import Observation

@MainActor
@Observable
final class ScanViewModel {

    enum Phase {
        case intro
        case scanning
        case results
    }

    var phase: Phase = .intro

    var filesSeen: Int = 0
    var physicalBytes: Int64 = 0
    var skippedPaths: Int = 0
    var currentPath: String = ""
    var scannedAt: Date?

    var children: [ChildTotal] { levels.last ?? [] }

    var navigationStack: [URL] = []

    private var levels: [[ChildTotal]] = []

    var currentRoot: URL? { navigationStack.last }

    var canGoBack: Bool { navigationStack.count > 1 }

    private var scanTask: Task<Void, Never>?
    private var saveTask: Task<Void, Never>?

    private let cacheURL: URL?

    init(cacheURL: URL? = nil) {
        self.cacheURL = cacheURL
    }

    var bytesText: String {
        ByteCountFormatter.string(fromByteCount: physicalBytes, countStyle: .file)
    }

    func start(root: URL = URL(fileURLWithPath: "/"), useCache: Bool = true) {
        reset()
        navigationStack = [root]
        levels = [[]]
        guard useCache, let cacheURL else {
            runScan(of: root)
            return
        }

        scanTask = Task {
            let snapshot = await Task.detached(priority: .userInitiated) {
                ScanSnapshot.read(from: cacheURL)
            }.value
            guard !Task.isCancelled else { return }
            if let snapshot, snapshot.root == root.path {
                self.restore(snapshot)
            } else {
                self.runScan(of: root)
            }
        }
    }

    func rescan() {
        start(root: navigationStack.first ?? URL(fileURLWithPath: "/"), useCache: false)
    }

    func url(for child: ChildTotal) -> URL? {
        currentRoot?.appendingPathComponent(child.name, isDirectory: child.isDirectory)
    }

    func enter(_ child: ChildTotal) {
        guard child.isDirectory, let url = url(for: child) else { return }
        navigationStack.append(url)
        levels.append(child.children ?? [])
        if child.children == nil { loadChildren(of: url) }
    }

    func goBack() {
        guard canGoBack else { return }
        scanTask?.cancel()
        navigationStack.removeLast()
        levels.removeLast()
    }

    func remove(_ child: ChildTotal) {
        guard !levels.isEmpty else { return }
        levels[levels.count - 1].removeAll { $0.id == child.id }
        for i in stride(from: levels.count - 1, to: 0, by: -1) {
            let name = navigationStack[i].lastPathComponent
            guard let j = levels[i - 1].firstIndex(where: { $0.name == name }) else { break }
            levels[i - 1][j].physicalTotal -= child.physicalTotal
            levels[i - 1][j].children = levels[i]
        }
        physicalBytes -= child.physicalTotal
        save()
    }

    private func runScan(of root: URL) {
        scanTask?.cancel()
        clearCounters()
        phase = .scanning

        scanTask = Task {
            let scanner = DirectoryScanner()
            for await p in scanner.scan(root: root) {
                guard !Task.isCancelled else { return }
                self.filesSeen = p.filesSeen
                self.physicalBytes = p.physicalBytes
                self.skippedPaths = p.skippedPaths
                if !p.currentPath.isEmpty { self.currentPath = p.currentPath }
                if let kids = p.children { self.levels = [kids] }
            }
            guard !Task.isCancelled else { return }
            self.scannedAt = Date()
            self.phase = .results
            self.save()
        }
    }

    private func restore(_ snapshot: ScanSnapshot) {
        filesSeen = snapshot.filesSeen
        physicalBytes = snapshot.physicalBytes
        skippedPaths = snapshot.skippedPaths
        scannedAt = snapshot.scannedAt
        levels = [snapshot.children]
        phase = .results
    }

    private func save() {
        guard let cacheURL, let root = navigationStack.first, let scannedAt else { return }
        let snapshot = ScanSnapshot(
            root: root.path, scannedAt: scannedAt,
            filesSeen: filesSeen, physicalBytes: physicalBytes, skippedPaths: skippedPaths,
            children: levels.first ?? [])
        let previous = saveTask
        saveTask = Task.detached(priority: .utility) {
            await previous?.value
            snapshot.write(to: cacheURL)
        }
    }

    private func loadChildren(of url: URL) {
        scanTask?.cancel()
        let level = levels.count - 1

        scanTask = Task {
            var kids: [ChildTotal] = []
            for await p in DirectoryScanner().scan(root: url) {
                if let c = p.children { kids = c }
            }
            guard !Task.isCancelled else { return }
            self.levels[level] = kids
        }
    }

    func cancel() {
        scanTask?.cancel()
        scanTask = nil
        phase = .intro
    }

    func reset() {
        scanTask?.cancel()
        scanTask = nil
        navigationStack = []
        levels = []
        clearCounters()
    }

    private func clearCounters() {
        filesSeen = 0
        physicalBytes = 0
        skippedPaths = 0
        currentPath = ""
        scannedAt = nil
    }
}

nonisolated private struct ScanSnapshot: Codable, Sendable {
    let root: String
    let scannedAt: Date
    let filesSeen: Int
    let physicalBytes: Int64
    let skippedPaths: Int
    let children: [ChildTotal]

    static func read(from url: URL) -> ScanSnapshot? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(ScanSnapshot.self, from: data)
    }

    func write(to url: URL) {
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(self) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
