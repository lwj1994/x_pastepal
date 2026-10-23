import Darwin
import Foundation
import Testing
@testable import XPastepalCore

struct LocalBackupStoreTests {
    @Test("Backup archives round-trip and have private permissions")
    func roundTripAndPermissions() throws {
        try withBackupStore { store in
            #expect(try store.list().isEmpty)
            let snapshot = makeSnapshot(text: "Private clipboard content")
            let date = Date(timeIntervalSince1970: 1_700_000_000.125)
            let backup = try #require(try store.create(snapshot, reason: "before-import", now: date))
            let loaded = try HistoryArchive.read(from: backup.url)
            let listed = try #require(try store.list().first)

            #expect(loaded.items == snapshot.items)
            #expect(listed.id == backup.url)
            #expect(listed.createdAt == date)
            #expect(listed.reason == "before-import")
            #expect(listed.byteCount == (try Data(contentsOf: backup.url)).count)
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: backup.url.path)
            let directoryAttributes = try FileManager.default.attributesOfItem(atPath: store.directory.path)
            #expect((fileAttributes[.posixPermissions] as? NSNumber)?.intValue == 0o600)
            #expect((directoryAttributes[.posixPermissions] as? NSNumber)?.intValue == 0o700)
        }
    }

    @Test("Only automatic backups are subject to the automatic interval")
    func automaticInterval() throws {
        try withBackupStore { store in
            let date = Date(timeIntervalSince1970: 1_700_000_000)
            let snapshot = makeSnapshot()
            try store.create(snapshot, reason: "before-import", now: date)
            #expect(try store.create(snapshot, reason: "automatic", minimumInterval: 21_600, now: date) != nil)
            #expect(try store.create(snapshot, reason: "automatic", minimumInterval: 21_600,
                                     now: date.addingTimeInterval(21_599)) == nil)
            #expect(try store.create(snapshot, reason: "before-restore", minimumInterval: 21_600,
                                     now: date.addingTimeInterval(21_599)) != nil)
            #expect(try store.create(snapshot, reason: "before-sync", minimumInterval: 21_600,
                                     now: date.addingTimeInterval(21_599)) != nil)
            #expect(try store.create(snapshot, reason: "automatic", minimumInterval: 21_600,
                                     now: date.addingTimeInterval(21_600)) != nil)
            #expect(try store.list().count == 5)
        }
    }

    @Test("Rotation keeps the newest 30 archives with distinct names")
    func countRotation() throws {
        try withBackupStore { store in
            let date = Date(timeIntervalSince1970: 1_700_000_000)
            var created: [LocalBackupInfo] = []
            for offset in 0..<32 {
                created.append(try #require(try store.create(
                    makeSnapshot(), reason: "automatic", now: date.addingTimeInterval(Double(offset))
                )))
            }
            let listed = try store.list()
            #expect(listed.count == 30)
            #expect(Set(listed.map(\.url)).count == 30)
            #expect(listed.first?.url == created.last?.url)
            #expect(listed.last?.url == created[2].url)
            #expect(!FileManager.default.fileExists(atPath: created[0].url.path))
            #expect(!FileManager.default.fileExists(atPath: created[1].url.path))
        }
    }

    @Test("Backups created at the same instant never overwrite one another")
    func identicalTimestampsRemainDistinct() throws {
        try withBackupStore { store in
            let date = Date(timeIntervalSince1970: 1_700_000_000)
            let first = try #require(try store.create(makeSnapshot(text: "Before"),
                                                       reason: "before-import", now: date))
            let second = try #require(try store.create(makeSnapshot(text: "After"),
                                                        reason: "before-import", now: date))
            #expect(first.url != second.url)
            #expect(try store.list().count == 2)
            #expect(try HistoryArchive.read(from: first.url).items.first?.text == "Before")
            #expect(try HistoryArchive.read(from: second.url).items.first?.text == "After")
        }
    }

    @Test("Rotation also enforces the combined 512 MiB budget using file metadata")
    func byteRotation() throws {
        try withBackupStore { store in
            let date = Date(timeIntervalSince1970: 1_700_000_000)
            let oldest = try #require(try store.create(makeSnapshot(), reason: "automatic", now: date))
            let recent = try #require(try store.create(makeSnapshot(), reason: "automatic",
                                                   now: date.addingTimeInterval(1)))
            // Sparse files exercise the real size policy without allocating huge clipboard payloads.
            try resize(oldest.url, to: 256 * 1_024 * 1_024)
            try resize(recent.url, to: 256 * 1_024 * 1_024)
            let newest = try #require(try store.create(makeSnapshot(), reason: "before-import",
                                                   now: date.addingTimeInterval(2)))
            let listed = try store.list()
            #expect(Set(listed.map(\.url)) == [recent.url, newest.url])
            #expect(listed.reduce(0) { $0 + $1.byteCount } <= 512 * 1_024 * 1_024)
            #expect(!FileManager.default.fileExists(atPath: oldest.url.path))
        }
    }

    @Test("Listing ignores unrelated files, partial writes, directories, and symbolic links")
    func ignoresUnmanagedFiles() throws {
        try withBackupStore { store in
            let backup = try #require(try store.create(makeSnapshot(), reason: "automatic"))
            let foreign = store.directory.appendingPathComponent("history.json")
            let partial = store.directory.appendingPathComponent(".xpastepal-partial.tmp")
            let malformed = store.directory.appendingPathComponent("xpastepal-backup_1_not-a-uuid_automatic.json")
            for url in [foreign, partial, malformed] { try Data("unrelated".utf8).write(to: url) }
            let link = store.directory.appendingPathComponent(
                "xpastepal-backup_1_\(UUID().uuidString)_automatic.json"
            )
            try FileManager.default.createSymbolicLink(at: link, withDestinationURL: backup.url)
            let folder = store.directory.appendingPathComponent(
                "xpastepal-backup_2_\(UUID().uuidString)_automatic.json"
            )
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
            #expect(try store.list().map(\.url) == [backup.url])

            // Corrupt content remains discoverable for recovery diagnostics; listing does not read it.
            try Data("invalid JSON".utf8).write(to: backup.url)
            #expect(try store.list().first?.byteCount == 12)
        }
    }

    @Test("Failed validation never rotates or overwrites existing archives")
    func validationFailurePreservesArchives() throws {
        try withBackupStore { store in
            let backup = try #require(try store.create(makeSnapshot(), reason: "automatic"))
            try resize(backup.url, to: 513 * 1_024 * 1_024)
            var invalid = makeSnapshot()
            invalid.maxItems = 0
            #expect(throws: (any Error).self) {
                try store.create(invalid, reason: "before-import")
            }
            let listed = try store.list()
            #expect(listed.count == 1)
            #expect(listed.first?.url == backup.url)
            #expect(listed.first?.byteCount == 513 * 1_024 * 1_024)
        }
    }

    @Test("An atomic write failure preserves existing archives and leaves no temporary file")
    func writeFailurePreservesArchives() throws {
        guard geteuid() != 0 else { return }
        try withBackupStore { store in
            let backup = try #require(try store.create(makeSnapshot(), reason: "automatic"))
            let original = try Data(contentsOf: backup.url)
            try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: store.directory.path)
            defer {
                try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: store.directory.path)
            }
            #expect(throws: (any Error).self) {
                try store.create(makeSnapshot(text: "New contents"), reason: "before-import")
            }
            #expect(try Data(contentsOf: backup.url) == original)
            #expect(try FileManager.default.contentsOfDirectory(atPath: store.directory.path).count == 1)
        }
    }

    @Test("The newly written backup survives rotation after the system clock moves backward")
    func clockRollbackKeepsNewRecoveryPoint() throws {
        try withBackupStore { store in
            let date = Date(timeIntervalSince1970: 1_700_000_000)
            for offset in 0..<30 {
                try store.create(makeSnapshot(), reason: "automatic", now: date.addingTimeInterval(Double(offset)))
            }
            let backup = try #require(try store.create(makeSnapshot(text: "Latest state"), reason: "before-restore",
                                                   now: date.addingTimeInterval(-100)))
            #expect(try store.list().count == 30)
            #expect(try HistoryArchive.read(from: backup.url).items.first?.text == "Latest state")
        }
    }

    private func makeSnapshot(text: String = "Saved clipboard") -> HistorySnapshot {
        HistorySnapshot(version: 1, items: [ClipItem(text: text)], collections: [], maxItems: 500,
                        excludedBundleIDs: "", retentionDays: 0, monitoringEnabled: true)
    }

    private func resize(_ url: URL, to size: UInt64) throws {
        let file = try FileHandle(forWritingTo: url)
        defer { try? file.close() }
        try file.truncate(atOffset: size)
    }

    private func withBackupStore(_ body: (LocalBackupStore) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("XPastepalBackupTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try body(LocalBackupStore(directory: directory))
    }
}
