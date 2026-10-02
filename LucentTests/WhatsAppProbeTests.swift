import Testing
import Foundation
import SQLite3
@testable import Lucent

private enum WhatsAppFixture {
    static let referenced = "Media/chatA@g.us/a/b/11111111-1111-1111-1111-111111111111.jpg"
    static let referencedByName = "Media/chatA@g.us/a/b/22222222-2222-2222-2222-222222222222.mp4"
    static let orphanSmall = "Media/chatA@g.us/a/b/33333333-3333-3333-3333-333333333333.jpg"
    static let orphanBig = "Media/chatA@g.us/c/d/44444444-4444-4444-4444-444444444444.mp4"
    static let orphanRecent = "Media/chatA@g.us/c/d/55555555-5555-5555-5555-555555555555.jpg"
    static let orphanOtherChat = "Media/chatB@s.whatsapp.net/e/f/66666666-6666-6666-6666-666666666666.jpg"

    static func makeContainer(withReferences: Bool = true) throws -> URL {
        let fm = FileManager.default
        let container = fm.temporaryDirectory.appendingPathComponent("LucentTests-\(UUID().uuidString)", isDirectory: true)
        let old = Date(timeIntervalSinceNow: -3 * 86_400)
        let files: [(String, Int, Date)] = [
            (referenced, 30_000, old), (referencedByName, 30_000, old),
            (orphanSmall, 50_000, old), (orphanBig, 100_000, old),
            (orphanRecent, 40_000, Date()), (orphanOtherChat, 20_000, old),
        ]
        for (path, size, modified) in files {
            let url = container.appendingPathComponent("Message/" + path)
            try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data(repeating: 7, count: size).write(to: url)
            try fm.setAttributes([.modificationDate: modified], ofItemAtPath: url.path)
        }

        var db: OpaquePointer?
        try #require(sqlite3_open(container.appendingPathComponent("ChatStorage.sqlite").path, &db) == SQLITE_OK)
        defer { sqlite3_close(db) }
        var sql = """
        CREATE TABLE ZWAMEDIAITEM (Z_PK INTEGER PRIMARY KEY, ZMEDIALOCALPATH VARCHAR, ZTITLE VARCHAR);
        CREATE TABLE ZWACHATSESSION (Z_PK INTEGER PRIMARY KEY, ZCONTACTJID VARCHAR, ZPARTNERNAME VARCHAR);
        INSERT INTO ZWACHATSESSION (ZCONTACTJID, ZPARTNERNAME) VALUES ('chatA@g.us', 'Family');
        """
        if withReferences {
            sql += """
            INSERT INTO ZWAMEDIAITEM (ZMEDIALOCALPATH) VALUES ('\(referenced)');
            INSERT INTO ZWAMEDIAITEM (ZTITLE) VALUES ('22222222-2222-2222-2222-222222222222.mp4');
            """
        }
        try #require(sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK)
        return container
    }

    static func exists(_ path: String, in container: URL) -> Bool {
        FileManager.default.fileExists(atPath: container.appendingPathComponent("Message/" + path).path)
    }
}

struct WhatsAppProbeTests {

    @Test("Only media no message links to counts as orphaned, per chat, recent files excluded")
    func orphanTotals() throws {
        let container = try WhatsAppFixture.makeContainer()
        defer { try? FileManager.default.removeItem(at: container) }

        let totals = try #require(WhatsAppMediaStore(container: container).orphanTotals())

        #expect(totals.map(\.chatID) == ["chatA@g.us", "chatB@s.whatsapp.net"])
        #expect(totals[0].name == "Family")
        #expect(totals[0].fileCount == 2)
        #expect(totals[0].physicalSize >= 150_000)
        #expect(totals[1].name == "chatB@s.whatsapp.net")
        #expect(totals[1].fileCount == 1)
    }

    @Test("One finding per chat above the size threshold, removable through the WhatsApp service")
    func findings() async throws {
        let container = try WhatsAppFixture.makeContainer()
        defer { try? FileManager.default.removeItem(at: container) }
        let store = WhatsAppMediaStore(container: container)

        let all = try await WhatsAppProbe(store: store, minimumReportableSize: 0).scan()
        #expect(all.count == 2)
        let family = try #require(all.first { $0.owner == "Family" })
        #expect(family.kind == "whatsAppOrphanMedia")
        #expect(family.domain == .system)
        #expect(family.whatsAppOrphanChat == "chatA@g.us")
        #expect(family.isActionable)
        #expect(family.risk == .safe)

        let large = try await WhatsAppProbe(store: store, minimumReportableSize: 100_000).scan()
        #expect(large.map(\.owner) == ["Family"])
    }

    @Test("A database with no media references yields nothing, never 'everything is orphaned'")
    func noReferencesMeansNoFindings() async throws {
        let container = try WhatsAppFixture.makeContainer(withReferences: false)
        defer { try? FileManager.default.removeItem(at: container) }
        let store = WhatsAppMediaStore(container: container)

        #expect(store.orphanTotals() == nil)
        #expect(try await WhatsAppProbe(store: store, minimumReportableSize: 0).scan().isEmpty)
        #expect(throws: WhatsAppMediaError.databaseUnreadable) {
            try WhatsAppMediaDeletionService(store: store, trash: { _ in }).removeOrphans(chatID: "chatA@g.us")
        }
        #expect(WhatsAppFixture.exists(WhatsAppFixture.orphanBig, in: container))
    }

    @Test("An unreadable WhatsApp database is reported as access needed, never as nothing found")
    func unreadableIsReported() async throws {
        let container = try WhatsAppFixture.makeContainer()
        defer { try? FileManager.default.removeItem(at: container) }
        let database = container.appendingPathComponent("ChatStorage.sqlite").path
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: database)

        let findings = try await WhatsAppProbe(store: WhatsAppMediaStore(container: container),
                                               minimumReportableSize: 0).scan()

        #expect(findings.map(\.kind) == ["whatsAppAccessNeeded"])
        #expect(findings.first?.isActionable == false)
        #expect(findings.first?.reclaimable.bytes == 0)
    }

    @Test("Removal moves only that chat's orphans into one folder and trashes it")
    func removeOrphans() throws {
        let container = try WhatsAppFixture.makeContainer()
        defer { try? FileManager.default.removeItem(at: container) }
        var trashed: [URL] = []
        let service = WhatsAppMediaDeletionService(store: WhatsAppMediaStore(container: container),
                                                   trash: { trashed.append($0) })

        try service.removeOrphans(chatID: "chatA@g.us")

        #expect(!WhatsAppFixture.exists(WhatsAppFixture.orphanSmall, in: container))
        #expect(!WhatsAppFixture.exists(WhatsAppFixture.orphanBig, in: container))
        #expect(WhatsAppFixture.exists(WhatsAppFixture.referenced, in: container))
        #expect(WhatsAppFixture.exists(WhatsAppFixture.referencedByName, in: container))
        #expect(WhatsAppFixture.exists(WhatsAppFixture.orphanRecent, in: container))
        #expect(WhatsAppFixture.exists(WhatsAppFixture.orphanOtherChat, in: container))

        #expect(trashed.count == 1)
        let staging = try #require(trashed.first)
        let fm = FileManager.default
        #expect(fm.fileExists(atPath: staging.appendingPathComponent(WhatsAppFixture.orphanSmall).path))
        #expect(fm.fileExists(atPath: staging.appendingPathComponent(WhatsAppFixture.orphanBig).path))
    }
}
