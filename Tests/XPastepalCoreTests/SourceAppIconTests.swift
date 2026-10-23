import AppKit
import Foundation
import Testing
@testable import XPastepalCore

@Suite(.serialized)
@MainActor
struct SourceAppIconTests {
    @Test("来源图标压缩为透明 PNG，小尺寸快照可解码")
    func thumbnailEncoding() throws {
        let data = try icon(.systemBlue)
        let bitmap = try #require(NSBitmapImageRep(data: data))
        #expect(bitmap.pixelsWide == 64)
        #expect(bitmap.pixelsHigh == 64)
        #expect(bitmap.hasAlpha)
        #expect(data.count <= HistoryArchive.maximumSourceIconBytes)
        #expect(SourceAppIconProvider().iconData(for: "") == nil)
        #expect(SourceAppIconProvider().iconData(for: "test.missing.\(UUID().uuidString)") == nil)
    }

    @Test("文字、链接、图片和文件记录保存来源图标，重启后无需安装来源应用")
    func captureAndPersistence() async throws {
        let png = try icon(.systemBlue)
        try await withStore(iconProvider: { $0 == "test.source" ? png : nil }) { store, board, directory in
            for text in ["text", "https://example.com"] {
                record(text, bundleID: "test.source", store: store, board: board)
            }
            board.clearContents()
            board.setData(png, forType: .png)
            store.captureCurrentClipboard(sourceApp: "Source", sourceBundleID: "test.source")
            let file = directory.appendingPathComponent("example.txt")
            try Data("file".utf8).write(to: file)
            board.clearContents()
            #expect(board.writeObjects([file as NSURL]))
            store.captureCurrentClipboard(sourceApp: "Source", sourceBundleID: "test.source")
            #expect(Set(store.items.map(\.kind)) == [.text, .link, .image, .file])
            #expect(store.items.allSatisfy { $0.sourceIconData == png })
            await store.flushPendingSaves()

            let restored = ClipboardStore(directory: directory, pasteboard: board, monitoring: false,
                                          sourceIconProvider: { _ in nil })
            await restored.backfillSourceIcons()
            #expect(restored.items == store.items)
            #expect(restored.errorMessage == nil)
            await restored.flushPendingSaves()
        }
    }

    @Test("重复内容跟随最新来源更新图标，来源不变且暂时找不到应用时保留快照")
    func deduplicationTracksSource() async throws {
        let blue = try icon(.systemBlue)
        let red = try icon(.systemRed)
        var available = ["test.first": blue, "test.second": red]
        try await withStore(iconProvider: { available[$0] }) { store, board, _ in
            record("same content", bundleID: "test.first", store: store, board: board)
            let first = try #require(store.items.first)
            store.togglePin(first)
            available.removeValue(forKey: "test.first")
            record("same content", bundleID: "test.first", store: store, board: board)
            #expect(store.items.first?.sourceIconData == blue)
            record("same content", bundleID: "test.second", store: store, board: board)
            #expect(store.items.count == 1)
            #expect(store.items.first?.id == first.id)
            #expect(store.items.first?.isPinned == true)
            #expect(store.items.first?.sourceIconData == red)
            record("same content", bundleID: "test.missing", store: store, board: board)
            #expect(store.items.first?.sourceBundleID == "test.missing")
            #expect(store.items.first?.sourceIconData == nil)
        }
    }

    @Test("旧历史缺少图标字段仍能读取，按应用补齐且不覆盖已有快照")
    func legacyBackfill() async throws {
        let blue = try icon(.systemBlue)
        let red = try icon(.systemRed)
        let legacy = ClipItem(text: "legacy", sourceBundleID: "test.source")
        let existing = ClipItem(text: "existing", sourceBundleID: "test.source", sourceIconData: red)
        let history = snapshot([legacy, existing, ClipItem(text: "another", sourceBundleID: "test.source"),
                                ClipItem(text: "unknown"), ClipItem(text: "missing", sourceBundleID: "test.missing")])
        var lookups: [String] = []
        try await withStore(history: history, iconProvider: { bundleID in
            lookups.append(bundleID)
            return bundleID == "test.source" ? blue : nil
        }) { store, board, directory in
            #expect(store.errorMessage == nil)
            #expect(store.items.first(where: { $0.id == legacy.id })?.sourceIconData == nil)
            await store.backfillSourceIcons()
            #expect(lookups.filter { $0 == "test.source" }.count == 1)
            #expect(!lookups.contains(""))
            #expect(store.items.first(where: { $0.id == legacy.id })?.sourceIconData == blue)
            #expect(store.items.first(where: { $0.id == existing.id })?.sourceIconData == red)
            #expect(store.items.first(where: { $0.text == "missing" })?.sourceIconData == nil)
            await store.flushPendingSaves()
            let restored = ClipboardStore(directory: directory, pasteboard: board, monitoring: false,
                                          sourceIconProvider: { _ in nil })
            #expect(restored.items == store.items)
        }
    }

    @Test("来源图标随备份、导出导入和同步载荷保留，计入容量且拒绝过大图标")
    func archivesAndSync() async throws {
        let png = try icon(.systemGreen)
        try await withStore(iconProvider: { _ in png }) { store, board, directory in
            record("exported", bundleID: "test.source", store: store, board: board)
            let item = try #require(store.items.first)
            #expect(HistoryArchive.payloadBytes(item) == item.text.utf8.count + png.count)
            await store.createBackup()
            let backup = try #require(store.backups.first { $0.reason == "manual" })
            #expect(try HistoryArchive.read(from: backup.url).items.first?.sourceIconData == png)
            let exported = directory.appendingPathComponent("export.json")
            try await store.exportHistory(to: exported)
            let imported = ClipboardStore(directory: directory.appendingPathComponent("imported"), pasteboard: board,
                                          monitoring: false, sourceIconProvider: { _ in nil })
            try await imported.importHistory(from: exported)
            #expect(imported.items.first?.sourceIconData == png)
            await imported.flushPendingSaves()

            let entry = SyncEntry(id: item.id, kind: .item, stamp: .init(counter: 1, deviceID: UUID().uuidString), item: item)
            let received = try JSONDecoder().decode(SyncEntry.self, from: JSONEncoder().encode(entry))
            #expect(try SyncMerge.merge([], [received]).first?.item?.sourceIconData == png)
            var oversized = item
            oversized.sourceIconData = Data(repeating: 0, count: HistoryArchive.maximumSourceIconBytes + 1)
            #expect(throws: HistoryError.self) { try HistoryArchive.validate(snapshot([oversized])) }
        }
    }

    private func icon(_ color: NSColor) throws -> Data {
        let image = NSImage(size: NSSize(width: 1_024, height: 1_024), flipped: false) { rect in
            color.setFill()
            NSBezierPath(roundedRect: rect.insetBy(dx: 64, dy: 64), xRadius: 128, yRadius: 128).fill()
            return true
        }
        return try #require(SourceAppIconProvider.pngData(from: image))
    }

    private func snapshot(_ items: [ClipItem]) -> HistorySnapshot {
        HistorySnapshot(version: 1, items: items, collections: [], maxItems: 500, excludedBundleIDs: "", retentionDays: 0)
    }

    private func record(_ text: String, bundleID: String, store: ClipboardStore, board: NSPasteboard) {
        board.clearContents()
        board.setString(text, forType: .string)
        store.captureCurrentClipboard(sourceApp: "Source", sourceBundleID: bundleID)
    }

    private func withStore(history: HistorySnapshot? = nil, iconProvider: @escaping (String) -> Data?,
                           body: (ClipboardStore, NSPasteboard, URL) async throws -> Void) async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("XPastepalSourceIconTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if let history { try JSONEncoder().encode(history).write(to: directory.appendingPathComponent("history.json")) }
        let board = NSPasteboard(name: .init("XPastepalSourceIconTests.\(UUID().uuidString)"))
        let store = ClipboardStore(directory: directory, pasteboard: board, monitoring: false, sourceIconProvider: iconProvider)
        do {
            try await body(store, board, directory)
            await store.flushPendingSaves()
            board.releaseGlobally()
            try FileManager.default.removeItem(at: directory)
        } catch {
            await store.flushPendingSaves()
            board.releaseGlobally()
            try? FileManager.default.removeItem(at: directory)
            throw error
        }
    }
}
