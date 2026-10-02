import Foundation

enum WhatsAppMediaError: Error, Equatable {
    case databaseUnreadable
}

struct WhatsAppMediaDeletionService {

    private let store: WhatsAppMediaStore
    private let trash: (URL) throws -> Void

    init(store: WhatsAppMediaStore = WhatsAppMediaStore(),
         trash: @escaping (URL) throws -> Void = { try FileManager.default.trashItem(at: $0, resultingItemURL: nil) }) {
        self.store = store
        self.trash = trash
    }

    func removeOrphans(chatID: String) throws {
        guard let files = store.orphanFiles(chatID: chatID) else { throw WhatsAppMediaError.databaseUnreadable }
        guard !files.isEmpty else { return }

        let fm = FileManager.default
        let staging = store.container
            .appendingPathComponent("Lucent removed WhatsApp media \(UUID().uuidString.prefix(8))", isDirectory: true)
        var createdDirectories: Set<URL> = []
        for file in files {
            let target = staging.appendingPathComponent(file.relativePath)
            let directory = target.deletingLastPathComponent()
            if createdDirectories.insert(directory).inserted {
                try fm.createDirectory(at: directory, withIntermediateDirectories: true)
            }
            try fm.moveItem(at: file.url, to: target)
        }
        try trash(staging)
    }
}
