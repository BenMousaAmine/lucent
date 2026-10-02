import Foundation
import SQLite3

struct WhatsAppOrphanTotal: Equatable {
    let chatID: String
    let name: String
    let fileCount: Int
    let physicalSize: Int64
}

struct WhatsAppOrphanFile: Equatable {
    let url: URL
    let relativePath: String
}

struct WhatsAppMediaStore {
    let container: URL
    let recentGrace: TimeInterval

    static var defaultContainer: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Group Containers/group.net.whatsapp.WhatsApp.shared")
    }

    init(container: URL = WhatsAppMediaStore.defaultContainer, recentGrace: TimeInterval = 24 * 3600) {
        self.container = container
        self.recentGrace = recentGrace
    }

    private var database: URL { container.appendingPathComponent("ChatStorage.sqlite") }
    private var messageRoot: URL { container.appendingPathComponent("Message") }
    private var mediaRoot: URL { messageRoot.appendingPathComponent("Media") }

    var isPresent: Bool { FileManager.default.fileExists(atPath: database.path) }

    var isReadable: Bool { FileManager.default.isReadableFile(atPath: database.path) }

    func orphanTotals() -> [WhatsAppOrphanTotal]? {
        guard let references = readReferences() else { return nil }
        var counts: [String: Int] = [:]
        var sizes: [String: Int64] = [:]
        forEachOrphan(references) { chatID, _, size in
            counts[chatID, default: 0] += 1
            sizes[chatID, default: 0] += size
        }
        return sizes.map { chatID, size in
            WhatsAppOrphanTotal(chatID: chatID, name: references.chatNames[chatID] ?? chatID,
                                fileCount: counts[chatID] ?? 0, physicalSize: size)
        }.sorted { $0.physicalSize > $1.physicalSize }
    }

    func orphanFiles(chatID: String) -> [WhatsAppOrphanFile]? {
        guard let references = readReferences() else { return nil }
        var files: [WhatsAppOrphanFile] = []
        forEachOrphan(references) { chat, file, _ in
            if chat == chatID { files.append(file) }
        }
        return files
    }

    private func forEachOrphan(_ references: References, _ body: (String, WhatsAppOrphanFile, Int64) -> Void) {
        let keys: [URLResourceKey] = [.isRegularFileKey, .totalFileAllocatedSizeKey, .contentModificationDateKey]
        guard let enumerator = FileManager.default.enumerator(
            at: mediaRoot, includingPropertiesForKeys: keys, options: [], errorHandler: nil
        ) else { return }
        let cutoff = Date().addingTimeInterval(-recentGrace)

        for case let url as URL in enumerator {
            guard let values = try? url.resourceValues(forKeys: Set(keys)), values.isRegularFile == true,
                  let marker = url.path.range(of: "/Message/Media/") else { continue }
            let relativePath = "Media/" + url.path[marker.upperBound...]
            let parts = relativePath.split(separator: "/")
            guard parts.count > 2,
                  !references.paths.contains(relativePath),
                  !references.fileNames.contains(url.lastPathComponent),
                  (values.contentModificationDate ?? .distantFuture) < cutoff else { continue }
            body(String(parts[1]), WhatsAppOrphanFile(url: url, relativePath: relativePath),
                 Int64(values.totalFileAllocatedSize ?? 0))
        }
    }

    private struct References {
        var paths: Set<String> = []
        var fileNames: Set<String> = []
        var chatNames: [String: String] = [:]
    }

    private func readReferences() -> References? {
        let fm = FileManager.default
        let copyDir = fm.temporaryDirectory.appendingPathComponent("Lucent-whatsapp-\(UUID().uuidString)")
        defer { try? fm.removeItem(at: copyDir) }
        guard (try? fm.createDirectory(at: copyDir, withIntermediateDirectories: true)) != nil else { return nil }
        let copy = copyDir.appendingPathComponent(database.lastPathComponent)
        guard (try? fm.copyItem(at: database, to: copy)) != nil else { return nil }
        for suffix in ["-wal", "-shm"] {
            try? fm.copyItem(at: URL(fileURLWithPath: database.path + suffix),
                             to: URL(fileURLWithPath: copy.path + suffix))
        }

        var db: OpaquePointer?
        guard sqlite3_open_v2(copy.path, &db, SQLITE_OPEN_READWRITE, nil) == SQLITE_OK else {
            sqlite3_close(db)
            return nil
        }
        defer { sqlite3_close(db) }

        var references = References()
        var tables: [String] = []
        Self.forEachRow(db, "SELECT name FROM sqlite_master WHERE type = 'table' AND sql NOT LIKE 'CREATE VIRTUAL TABLE%'") {
            if let name = Self.text($0, 0) { tables.append(name) }
        }
        let fileName = try? NSRegularExpression(
            pattern: "[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}\\.[A-Za-z0-9]+")

        for table in tables {
            var columns: [String] = []
            Self.forEachRow(db, "PRAGMA table_info(\"\(table)\")") {
                let type = (Self.text($0, 2) ?? "").uppercased()
                if let name = Self.text($0, 1), ["", "TEXT", "VARCHAR"].contains(type) { columns.append(name) }
            }
            for column in columns {
                let sql = "SELECT \"\(column)\" FROM \"\(table)\" WHERE typeof(\"\(column)\") = 'text' "
                    + "AND (\"\(column)\" LIKE '%Media/%' OR \"\(column)\" LIKE '%-%-%-%-%.%')"
                Self.forEachRow(db, sql) {
                    guard let value = Self.text($0, 0) else { return }
                    if let range = value.range(of: "Media/") {
                        references.paths.insert(String(value[range.lowerBound...]))
                    }
                    let whole = NSRange(value.startIndex..., in: value)
                    fileName?.enumerateMatches(in: value, range: whole) { match, _, _ in
                        if let match, let range = Range(match.range, in: value) {
                            references.fileNames.insert(String(value[range]))
                        }
                    }
                }
            }
        }
        Self.forEachRow(db, "SELECT ZCONTACTJID, ZPARTNERNAME FROM ZWACHATSESSION") {
            if let chatID = Self.text($0, 0), let name = Self.text($0, 1) { references.chatNames[chatID] = name }
        }
        return references.paths.isEmpty ? nil : references
    }

    private static func forEachRow(_ db: OpaquePointer?, _ sql: String, _ body: (OpaquePointer) -> Void) {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement else { return }
        defer { sqlite3_finalize(statement) }
        while sqlite3_step(statement) == SQLITE_ROW { body(statement) }
    }

    private static func text(_ statement: OpaquePointer, _ column: Int32) -> String? {
        sqlite3_column_text(statement, column).map { String(cString: $0) }
    }
}
