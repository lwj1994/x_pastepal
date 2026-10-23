import AppKit
import CloudKit
import Foundation
import Testing
@testable import XPastepalCore

@Suite("Backup and multi-Mac synchronization")
@MainActor
struct ClipboardSyncTests {
    @Test("Legacy pinned libraries remain readable beyond the archive item limit")
    func legacyPrimaryCapacity() async throws {
        try await withSyncFixtures { a, _ in
            let pinned = (0...20_000).map { ClipItem(text: "Pinned \($0)", isPinned: true) }
            let snapshot = HistorySnapshot(version: 1, items: pinned, collections: [],
                                           maxItems: 500, excludedBundleIDs: "", retentionDays: 0)
            try HistoryArchive.write(snapshot, to: a.store.historyFileURL, enforceArchiveLimit: false)
            let reopened = ClipboardStore(directory: a.directory, pasteboard: a.board, monitoring: false)
            #expect(reopened.errorMessage == nil)
            #expect(reopened.items.count == pinned.count)
            #expect(throws: HistoryError.self) { try HistoryArchive.validate(snapshot) }
        }
    }

    @Test("Cloud configuration rejects CLI tests safely and nested retry delays are respected")
    func cloudPrerequisitesAndRetry() {
        #expect(CloudKitTransport.configurationError != nil)
        #expect(throws: (any Error).self) { try CloudKitTransport() }
        let child = CKError(.requestRateLimited, userInfo: [CKErrorRetryAfterKey: 420.0])
        let parent = CKError(.partialFailure, userInfo: [CKPartialErrorsByItemIDKey: ["entry": child]])
        #expect(ClipboardStore.cloudRetryDelay(parent) == 420)
    }

    @Test("Two offline Macs converge; deletion wins and survives restart")
    func offlineMergeAndDeletion() async throws {
        try await withSyncFixtures { a, b in
            let cloud = MemorySyncTransport()
            let first = try #require(a.store.addText("from A"))
            b.store.addText("from B")
            try await a.store.synchronize(using: cloud)
            try await b.store.synchronize(using: cloud)
            try await a.store.synchronize(using: cloud)
            #expect(Set(a.store.items.map(\.text)) == ["from A", "from B"])
            #expect(a.store.items == b.store.items)
            a.store.delete(first)
            b.store.updateText(first, text: "offline edit after deletion")
            try await b.store.synchronize(using: cloud)
            try await a.store.synchronize(using: cloud)
            try await b.store.synchronize(using: cloud)
            #expect(!a.store.items.contains { $0.id == first.id })
            #expect(!b.store.items.contains { $0.id == first.id })
            await a.store.flushPendingSaves()
            let reopened = ClipboardStore(directory: a.directory, pasteboard: a.board, monitoring: false)
            try await reopened.synchronize(using: cloud)
            #expect(reopened.items == b.store.items)
            await reopened.flushPendingSaves()
        }
    }

    @Test("Concurrent edits resolve deterministically, independent of merge direction")
    func concurrentEdits() throws {
        let item = ClipItem(text: "original")
        var edited = item
        edited.text = "edited"
        let low = SyncEntry(id: item.id, kind: .item,
                            stamp: .init(counter: 8, deviceID: "00000000-0000-0000-0000-000000000001"), item: item)
        let high = SyncEntry(id: item.id, kind: .item,
                             stamp: .init(counter: 8, deviceID: "00000000-0000-0000-0000-000000000002"), item: edited)
        #expect(try SyncMerge.merge([low], [high]) == [high])
        #expect(try SyncMerge.merge([high], [low]) == [high])
        var deleted = low
        deleted.item = nil
        #expect(try SyncMerge.merge([high], [deleted]) == [deleted])
    }

    @Test("Deleted collections ungroup content, while file references stay on their Mac")
    func collectionsAndLocalFiles() async throws {
        try await withSyncFixtures { a, b in
            let cloud = MemorySyncTransport()
            a.store.addCollection(name: "Shared")
            let collection = try #require(a.store.collections.first)
            let item = try #require(a.store.addText("shared text"))
            a.store.move(item, to: collection.id)
            a.board.clearContents()
            a.board.writeObjects([NSURL(fileURLWithPath: "/tmp/xpastepal-local-only")])
            a.store.captureCurrentClipboard(sourceApp: "Test", sourceBundleID: "example.test")
            try await a.store.synchronize(using: cloud)
            try await b.store.synchronize(using: cloud)
            #expect(a.store.items.contains { $0.kind == .file })
            #expect(!b.store.items.contains { $0.kind == .file })
            #expect(b.store.items.first?.collectionID == collection.id)
            b.store.deleteCollection(collection)
            try await b.store.synchronize(using: cloud)
            try await a.store.synchronize(using: cloud)
            #expect(a.store.collections.isEmpty)
            #expect(a.store.items.first(where: { $0.id == item.id })?.collectionID == nil)
        }
    }

    @Test("Account changes and failed uploads retain local work for retry")
    func accountAndNetworkFailures() async throws {
        try await withSyncFixtures { a, _ in
            let cloud = MemorySyncTransport()
            a.store.addText("keep me")
            await cloud.setFailPush(true)
            await #expect(throws: SyncError.self) { try await a.store.synchronize(using: cloud) }
            #expect(a.store.items.count == 1)
            #expect(a.store.lastSyncDate == nil)
            await cloud.setFailPush(false)
            try await a.store.synchronize(using: cloud)
            #expect(await cloud.count() == 1)
            a.store.addText("new local")
            await cloud.setAccount("another-account")
            await #expect(throws: SyncError.self) { try await a.store.synchronize(using: cloud) }
            #expect(await cloud.count() == 1)
            #expect(a.store.items.count == 2)
        }
    }

    @Test("Invalid remote payloads never partially replace local history")
    func malformedRemote() async throws {
        try await withSyncFixtures { a, _ in
            let cloud = MemorySyncTransport()
            let local = try #require(a.store.addText("valid local"))
            let bad = ClipItem(text: "", kind: .image)
            await cloud.inject(SyncEntry(id: bad.id, kind: .item,
                                          stamp: .init(counter: 2, deviceID: UUID().uuidString), item: bad))
            await #expect(throws: (any Error).self) { try await a.store.synchronize(using: cloud) }
            #expect(a.store.items == [local])
            #expect(a.store.lastSyncDate == nil)
        }
    }

    @Test("Recovery recreates deleted IDs and never restores another device's identity")
    func recoverDeletedContent() async throws {
        try await withSyncFixtures { a, b in
            let cloud = MemorySyncTransport()
            let original = try #require(a.store.addText("recover this"))
            a.store.addCollection(name: "Recovered folder")
            let collection = try #require(a.store.collections.first)
            a.store.move(original, to: collection.id)
            await a.store.createBackup()
            let backup = try #require(a.store.backups.first(where: { $0.reason == "manual" }))
            try await a.store.synchronize(using: cloud)
            a.store.delete(original)
            a.store.deleteCollection(collection)
            try await a.store.synchronize(using: cloud)
            await a.store.restoreBackup(backup)
            let recovered = try #require(a.store.items.first)
            #expect(recovered.text == original.text)
            #expect(recovered.id != original.id)
            #expect(recovered.collectionID != collection.id)
            #expect(recovered.collectionID == a.store.collections.first?.id)
            try await a.store.synchronize(using: cloud)
            try await b.store.synchronize(using: cloud)
            #expect(b.store.items == a.store.items)
            let aSnapshot = try HistoryArchive.read(from: a.store.historyFileURL)
            let bSnapshot = try HistoryArchive.read(from: b.store.historyFileURL)
            #expect(aSnapshot.syncState?.deviceID != bSnapshot.syncState?.deviceID)
        }
    }

    @Test("Corrupt primary recovery preserves original bytes and merges a valid backup")
    func corruptRecovery() async throws {
        try await withSyncFixtures { a, _ in
            a.store.addText("protected")
            await a.store.createBackup()
            await a.store.flushPendingSaves()
            let bytes = Data("corrupt primary".utf8)
            try bytes.write(to: a.store.historyFileURL)
            let reopened = ClipboardStore(directory: a.directory, pasteboard: a.board, monitoring: false)
            #expect(reopened.errorMessage != nil)
            await reopened.refreshBackups()
            let backup = try #require(reopened.backups.first(where: { $0.reason == "manual" }))
            await reopened.restoreBackup(backup)
            await reopened.flushPendingSaves()
            #expect(reopened.items.map(\.text) == ["protected"])
            let preserved = try FileManager.default.contentsOfDirectory(at: a.directory, includingPropertiesForKeys: nil)
                .filter { $0.lastPathComponent.hasPrefix("history-corrupt-") }
            #expect(preserved.count == 1)
            #expect(try Data(contentsOf: #require(preserved.first)) == bytes)
            #expect(try HistoryArchive.read(from: reopened.historyFileURL).items.map(\.text) == ["protected"])
        }
    }

    @Test("Disk failure prevents upload even when changes exist in memory")
    func diskFailurePreventsPush() async throws {
        try await withSyncFixtures { a, _ in
            let path = a.directory.appendingPathComponent("not-a-directory")
            try Data("blocked".utf8).write(to: path)
            let blocked = ClipboardStore(directory: path, pasteboard: a.board, monitoring: false)
            blocked.addText("must not upload")
            let cloud = MemorySyncTransport()
            await #expect(throws: HistoryError.self) { try await blocked.synchronize(using: cloud) }
            #expect(await cloud.count() == 0)
            #expect(blocked.items.count == 1)
            await blocked.flushPendingSaves()
        }
    }

    @Test("Disabling sync while a download is pending prevents merge and upload")
    func disablingDuringFetch() async throws {
        try await withSyncFixtures { a, _ in
            let cloud = MemorySyncTransport()
            let item = ClipItem(text: "remote")
            await cloud.inject(SyncEntry(id: item.id, kind: .item,
                                          stamp: .init(counter: 1, deviceID: UUID().uuidString), item: item))
            await cloud.pauseFetch()
            let operation = Task { try await a.store.synchronize(using: cloud) }
            await cloud.waitUntilFetching()
            await a.store.setCloudSyncEnabled(false)
            await cloud.resumeFetch()
            try await operation.value
            #expect(a.store.items.isEmpty)
            #expect(a.store.lastSyncDate == nil)
            #expect(!a.store.cloudSyncEnabled)
        }
    }

    @Test("Disabling sync cancels queued upload batches")
    func disablingDuringPush() async throws {
        try await withSyncFixtures { a, _ in
            let cloud = MemorySyncTransport()
            a.store.addText("pending upload")
            await cloud.pausePush()
            let operation = Task { try await a.store.synchronize(using: cloud) }
            await cloud.waitUntilPushing()
            await a.store.setCloudSyncEnabled(false)
            await cloud.resumePush()
            await #expect(throws: CancellationError.self) { try await operation.value }
            #expect(await cloud.count() == 0)
            #expect(a.store.items.count == 1)
            #expect(!a.store.cloudSyncEnabled)
            #expect(a.store.syncStatus.contains("已关闭"))
        }
    }
}

private actor MemorySyncTransport: ClipboardSyncTransport {
    private var records: [String: SyncEntry] = [:]
    private var account = "test-account"
    private var failPush = false
    private var paused = false
    private var fetching = false
    private var fetchContinuation: CheckedContinuation<Void, Never>?
    private var startedContinuation: CheckedContinuation<Void, Never>?
    private var pushPaused = false
    private var pushing = false
    private var pushContinuation: CheckedContinuation<Void, Never>?
    private var pushStartedContinuation: CheckedContinuation<Void, Never>?

    func accountID() async throws -> String { account }
    func fetch() async throws -> [SyncEntry] {
        fetching = true
        startedContinuation?.resume()
        startedContinuation = nil
        if paused { await withCheckedContinuation { fetchContinuation = $0 } }
        return Array(records.values)
    }
    func push(_ entries: [SyncEntry]) async throws {
        pushing = true
        pushStartedContinuation?.resume()
        pushStartedContinuation = nil
        if pushPaused { await withCheckedContinuation { pushContinuation = $0 } }
        try Task.checkCancellation()
        if failPush { throw SyncError.unavailable("offline") }
        // Models conflict retry convergence without touching Apple's services.
        let merged = try SyncMerge.merge(Array(records.values), entries)
        records = Dictionary(uniqueKeysWithValues: merged.map { ($0.key, $0) })
    }
    func setFailPush(_ value: Bool) { failPush = value }
    func setAccount(_ value: String) { account = value }
    func count() -> Int { records.count }
    func inject(_ entry: SyncEntry) { records[entry.key] = entry }
    func pauseFetch() { paused = true }
    func waitUntilFetching() async {
        if !fetching { await withCheckedContinuation { startedContinuation = $0 } }
    }
    func resumeFetch() {
        paused = false
        fetchContinuation?.resume()
        fetchContinuation = nil
    }
    func pausePush() { pushPaused = true }
    func waitUntilPushing() async {
        if !pushing { await withCheckedContinuation { pushStartedContinuation = $0 } }
    }
    func resumePush() {
        pushPaused = false
        pushContinuation?.resume()
        pushContinuation = nil
    }
}

@MainActor
private final class SyncFixture {
    let directory: URL
    let board: NSPasteboard
    let store: ClipboardStore
    init() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("XPastepalSyncTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        board = NSPasteboard(name: .init("XPastepalSyncTests.\(UUID().uuidString)"))
        store = ClipboardStore(directory: directory, pasteboard: board, monitoring: false)
    }
    func close() async {
        await store.flushPendingSaves()
        board.releaseGlobally()
        try? FileManager.default.removeItem(at: directory)
    }
}

@MainActor
private func withSyncFixtures(_ body: (SyncFixture, SyncFixture) async throws -> Void) async throws {
    let a = try SyncFixture()
    let b = try SyncFixture()
    do {
        try await body(a, b)
        await a.close()
        await b.close()
    } catch {
        await a.close()
        await b.close()
        throw error
    }
}
