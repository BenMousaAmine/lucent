import AppKit
import Observation

@MainActor
@Observable
final class TrashViewModel {

    enum State {
        case loading
        case noAccess
        case loaded([ChildTotal])
    }

    private(set) var state: State = .loading

    private let trashURL: URL
    private var task: Task<Void, Never>?

    init(trashURL: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".Trash")) {
        self.trashURL = trashURL
    }

    var items: [ChildTotal] {
        if case .loaded(let items) = state { return items }
        return []
    }

    var totalBytes: Int64 { items.reduce(0) { $0 + $1.physicalTotal } }

    func refresh() {
        task?.cancel()
        task = Task {
            var last: ScanProgress?
            for await progress in DirectoryScanner().scan(root: trashURL) { last = progress }
            guard !Task.isCancelled else { return }
            let children = last?.children ?? []
            let denied = children.isEmpty && (last?.skippedPaths ?? 0) > 0
            self.state = denied ? .noAccess : .loaded(children.filter { $0.name != ".DS_Store" })
        }
    }

    func openInFinder() {
        NSWorkspace.shared.open(trashURL)
    }
}
