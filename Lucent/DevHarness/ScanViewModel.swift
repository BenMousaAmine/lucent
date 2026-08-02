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

    var children: [ChildTotal] = []

    var navigationStack: [URL] = []

    var currentRoot: URL? { navigationStack.last }

    var canGoBack: Bool { navigationStack.count > 1 }

    private var scanTask: Task<Void, Never>?

    var bytesText: String {
        ByteCountFormatter.string(fromByteCount: physicalBytes, countStyle: .file)
    }

    func start(root: URL = URL(fileURLWithPath: "/")) {
        reset()
        navigationStack = [root]
        runScan(of: root)
    }

    func enter(_ child: ChildTotal) {
        guard child.isDirectory else { return }
        navigationStack.append(child.url)
        runScan(of: child.url)
    }

    func goBack() {
        guard canGoBack else { return }
        navigationStack.removeLast()
        if let parent = navigationStack.last { runScan(of: parent) }
    }

    private func runScan(of root: URL) {
        scanTask?.cancel()
        clearCounters()
        phase = .scanning

        scanTask = Task {
            let scanner = DirectoryScanner()
            for await p in scanner.scan(root: root) {
                self.filesSeen = p.filesSeen
                self.physicalBytes = p.physicalBytes
                self.skippedPaths = p.skippedPaths
                if !p.currentPath.isEmpty { self.currentPath = p.currentPath }
                if let kids = p.children { self.children = kids }
            }
            self.phase = .results
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
        clearCounters()
    }

    private func clearCounters() {
        filesSeen = 0
        physicalBytes = 0
        skippedPaths = 0
        currentPath = ""
        children = []
    }
}
