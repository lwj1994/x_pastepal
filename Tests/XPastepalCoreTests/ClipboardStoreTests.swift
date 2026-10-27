import AppKit
import Foundation
import Testing
@testable import XPastepalCore

@Suite(.serialized)
@MainActor
struct ClipboardStoreTests {
    @Test("重复采集保留固定状态、收藏夹和最初创建时间")
    func deduplicationPreservesMetadata() async throws {
        try await withFixture { fixture in
            fixture.record("同一段文本")
            let initial = try #require(fixture.store.items.first)
            fixture.store.togglePin(initial)
            fixture.store.addCollection(name: "开发")
            let collection = try #require(fixture.store.collections.first)
            fixture.store.move(initial, to: collection.id)
            fixture.record("另一段文本")
            fixture.record("同一段文本", app: "终端", bundleID: "com.apple.Terminal")

            let duplicate = try #require(fixture.store.items.first)
            #expect(fixture.store.items.count == 2)
            #expect(duplicate.id == initial.id)
            #expect(duplicate.createdAt == initial.createdAt)
            #expect(duplicate.lastCopiedAt >= initial.lastCopiedAt)
            #expect(duplicate.isPinned)
            #expect(duplicate.collectionID == collection.id)
            #expect(duplicate.sourceApp == "终端")
        }
    }

    @Test("历史、收藏夹和设置写入后可完整恢复")
    func persistenceRoundTrip() async throws {
        try await withFixture { fixture in
            fixture.record("https://example.com/docs")
            fixture.store.addCollection(name: "资料")
            fixture.store.togglePin(try #require(fixture.store.items.first))
            fixture.store.maxItems = 150
            fixture.store.retentionDays = 30
            fixture.store.excludedBundleIDs = "com.example.secret\ncom.example.other"
            await fixture.store.flushPendingSaves()

            let restored = ClipboardStore(directory: fixture.directory, pasteboard: fixture.board, monitoring: false)
            #expect(restored.items == fixture.store.items)
            #expect(restored.collections == fixture.store.collections)
            #expect(restored.items.first?.kind == .link)
            #expect(restored.maxItems == 150)
            #expect(restored.retentionDays == 30)
            #expect(restored.excludedBundleIDs == fixture.store.excludedBundleIDs)
            #expect(restored.errorMessage == nil)
        }
    }

    @Test("自动记录偏好跨启动保留，退出暂停不会改写偏好")
    func monitoringPreferenceRoundTrip() async throws {
        try await withFixture { fixture in
            fixture.store.startMonitoring()
            #expect(fixture.store.isMonitoring)
            fixture.store.stopMonitoring()
            await fixture.store.flushPendingSaves()

            let restored = ClipboardStore(directory: fixture.directory, pasteboard: fixture.board)
            #expect(!restored.isMonitoring)
            restored.startMonitoring()
            #expect(restored.isMonitoring)
            restored.stopMonitoring(persistPreference: false)
            #expect(!restored.isMonitoring)
            // 退出期间的其他设置写入也应使用持久化偏好，而非已停止的运行时状态。
            restored.addCollection(name: "退出前保存")
            await restored.flushPendingSaves()

            let reopened = ClipboardStore(directory: fixture.directory, pasteboard: fixture.board)
            #expect(reopened.isMonitoring)
            reopened.stopMonitoring(persistPreference: false)
        }
    }

    @Test("旧历史默认启用采集，显式关闭仅作用于当前实例")
    func legacyMonitoringPreferenceAndExplicitOverride() async throws {
        try await withFixture(history: TestSnapshot()) { fixture in
            let legacy = ClipboardStore(directory: fixture.directory, pasteboard: fixture.board)
            #expect(legacy.isMonitoring)
            #expect(legacy.errorMessage == nil)
            legacy.stopMonitoring(persistPreference: false)

            let overridden = ClipboardStore(directory: fixture.directory, pasteboard: fixture.board, monitoring: false)
            #expect(!overridden.isMonitoring)
            overridden.addCollection(name: "测试模式的设置")
            await overridden.flushPendingSaves()

            let reopened = ClipboardStore(directory: fixture.directory, pasteboard: fixture.board)
            #expect(reopened.isMonitoring)
            reopened.stopMonitoring(persistPreference: false)
        }
    }

    @Test("查询支持内容、应用、重音折叠和组合筛选")
    func searchAndFilters() async throws {
        try await withFixture { fixture in
            fixture.record("Café Swift snippets", app: "Xcode", bundleID: "com.apple.dt.Xcode")
            let snippet = try #require(fixture.store.items.first)
            fixture.store.addCollection(name: "代码")
            let collection = try #require(fixture.store.collections.first)
            fixture.store.move(snippet, to: collection.id)
            fixture.store.togglePin(snippet)
            fixture.record("https://swift.org")

            #expect(fixture.store.filteredItems(query: "CAFE xcode").map(\.id) == [snippet.id])
            #expect(fixture.store.filteredItems(query: "Swift", kind: .link).count == 1)
            #expect(fixture.store.filteredItems(query: "", collectionID: collection.id, pinnedOnly: true).map(\.id) == [snippet.id])
            #expect(fixture.store.filteredItems(query: "不存在").isEmpty)
            fixture.store.deleteCollection(collection)
            #expect(fixture.store.items.first(where: { $0.id == snippet.id })?.collectionID == nil)
            #expect(fixture.store.items.count == 2)
        }
    }

    @Test("密码来源、机密标记及用户配置的来源不会进入历史")
    func exclusions() async throws {
        try await withFixture { fixture in
            fixture.record("password", bundleID: "com.1password.1password")
            fixture.record("password", bundleID: "com.apple.Passwords")
            fixture.store.excludedBundleIDs = "com.example.Secret, com.example.private.*\ncom.example.other"
            fixture.record("secret", bundleID: "COM.EXAMPLE.SECRET")
            fixture.record("secret", bundleID: "com.example.private.editor")
            for marker in ["org.nspasteboard.ConcealedType", "org.nspasteboard.TransientType"] {
                fixture.board.clearContents()
                fixture.board.setString("secret", forType: .string)
                fixture.board.setData(Data(), forType: NSPasteboard.PasteboardType(marker))
                fixture.store.captureCurrentClipboard(sourceApp: "测试", sourceBundleID: "com.example.safe")
            }
            #expect(fixture.store.items.isEmpty)
            fixture.record("allowed", bundleID: "com.example.safely")
            #expect(fixture.store.items.count == 1)
        }
    }

    @Test("过期和条数限制不会删除固定记录")
    func retentionKeepsPinnedItems() async throws {
        let oldDate = Date().addingTimeInterval(-90 * 86_400)
        let pinned = ClipItem(createdAt: oldDate, text: "固定的旧记录", isPinned: true)
        let expired = ClipItem(createdAt: oldDate, text: "过期的旧记录")
        try await withFixture(history: TestSnapshot(items: [pinned, expired], retentionDays: 7)) { fixture in
            #expect(fixture.store.items.map(\.id) == [pinned.id])
            fixture.store.maxItems = 2
            fixture.record("较早的新记录")
            fixture.record("最新记录")
            #expect(fixture.store.items.count == 2)
            #expect(fixture.store.items.contains(where: { $0.id == pinned.id }))
            #expect(fixture.store.items.contains(where: { $0.text == "最新记录" }))
            fixture.store.maxItems = 1
            #expect(fixture.store.items.map(\.id) == [pinned.id])
            fixture.store.clearUnpinned()
            #expect(fixture.store.items.map(\.id) == [pinned.id])
        }
    }

    @Test("富文本复制保留格式，编辑后和纯文本复制清除旧格式")
    func richTextCopyAndEditing() async throws {
        try await withFixture { fixture in
            let richString = NSAttributedString(string: "Hello Swift", attributes: [.font: NSFont.boldSystemFont(ofSize: 15)])
            let rtf = try richString.data(from: NSRange(location: 0, length: richString.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
            fixture.board.clearContents()
            fixture.board.setData(rtf, forType: .rtf)
            fixture.store.captureCurrentClipboard(sourceApp: "测试", sourceBundleID: "test.app")
            let richItem = try #require(fixture.store.items.first)
            #expect(richItem.text == "Hello Swift")
            #expect(richItem.rtfData == rtf)
            #expect(fixture.store.copy(richItem))
            #expect(fixture.board.data(forType: .rtf) == rtf)
            #expect(fixture.store.copy(richItem, plainText: true))
            #expect(fixture.board.string(forType: .string) == "Hello Swift")
            #expect(fixture.board.data(forType: .rtf) == nil)
            fixture.store.updateText(richItem, text: "https://example.com")
            #expect(fixture.store.items.first?.kind == .link)
            #expect(fixture.store.items.first?.rtfData == nil)
            #expect(fixture.store.copy(try #require(fixture.store.items.first)))
            #expect(fixture.board.string(forType: .string) == "https://example.com")
        }
    }

    @Test("图片和多个文件可从真实剪贴板类型采集并回写")
    func imageAndFileRoundTrip() async throws {
        try await withFixture { fixture in
            let png = try #require(Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+j1ioAAAAASUVORK5CYII="))
            fixture.board.clearContents()
            fixture.board.setData(png, forType: .png)
            fixture.store.captureCurrentClipboard(sourceApp: "截图", sourceBundleID: "test.screenshot")
            let image = try #require(fixture.store.items.first)
            #expect(image.kind == .image)
            #expect(image.imageData == png)
            #expect(fixture.store.copy(image))
            #expect(fixture.board.data(forType: .png) == png)

            let paths = [fixture.directory.appendingPathComponent("一.txt"), fixture.directory.appendingPathComponent("二.txt")]
            for path in paths { try Data("file".utf8).write(to: path) }
            fixture.board.clearContents()
            #expect(fixture.board.writeObjects(paths as [NSURL]))
            fixture.store.captureCurrentClipboard(sourceApp: "Finder", sourceBundleID: "com.apple.finder")
            let files = try #require(fixture.store.items.first)
            #expect(files.kind == .file)
            #expect(files.filePaths == paths.map(\.path))
            #expect(fixture.store.copy(files))
            let pastedURLs = fixture.board.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL]
            #expect(pastedURLs == paths)
            await fixture.store.flushPendingSaves()
            let restored = ClipboardStore(directory: fixture.directory, pasteboard: fixture.board, monitoring: false)
            #expect(restored.items.contains(where: { $0.imageData == png }))
            #expect(restored.items.contains(where: { $0.filePaths == files.filePaths }))
        }
    }

    @Test("启动跳过已有剪贴板，自身复制不重新采集")
    func monitoringDoesNotRecaptureOwnCopy() async throws {
        try await withFixture(initialClipboard: "启动前的敏感内容", monitoring: true) { fixture in
            try await Task.sleep(for: .milliseconds(800))
            #expect(fixture.store.items.isEmpty)
            fixture.board.clearContents()
            fixture.board.setString("轮询自动采集的内容", forType: .string)
            try await Task.sleep(for: .milliseconds(800))
            #expect(fixture.store.items.first?.text == "轮询自动采集的内容")
            fixture.record("正常记录", app: "来源应用", bundleID: "test.source")
            let item = try #require(fixture.store.items.first)
            #expect(fixture.store.copy(item))
            try await Task.sleep(for: .milliseconds(800))
            #expect(fixture.store.items.count == 2)
            #expect(fixture.store.items.first?.sourceApp == "来源应用")
            #expect(fixture.store.items.first?.id == item.id)
        }
    }

    @Test("损坏的历史文件被保留，后续操作不会静默覆盖")
    func corruptedHistoryIsNotOverwritten() async throws {
        try await withFixture { fixture in
            let invalidData = Data("{ broken json".utf8)
            try invalidData.write(to: fixture.store.historyFileURL)
            let restored = ClipboardStore(directory: fixture.directory, pasteboard: fixture.board, monitoring: false)
            #expect(restored.errorMessage != nil)
            restored.addCollection(name: "新收藏夹")
            fixture.board.clearContents()
            fixture.board.setString("新内容", forType: .string)
            restored.captureCurrentClipboard(sourceApp: "测试", sourceBundleID: "test.app")
            await restored.flushPendingSaves()
            #expect(try Data(contentsOf: restored.historyFileURL) == invalidData)
        }
    }

    @Test("磁盘写入失败可见，修复目标目录后能够再次保存")
    func writeFailureAndRecovery() async throws {
        try await withFixture { fixture in
            let invalidDirectory = fixture.directory.appendingPathComponent("blocked")
            try Data("not a directory".utf8).write(to: invalidDirectory)
            let store = ClipboardStore(directory: invalidDirectory, pasteboard: fixture.board, monitoring: false)
            store.addCollection(name: "保留在内存的收藏夹")
            await store.flushPendingSaves()
            await Task.yield()
            #expect(store.errorMessage != nil)
            try FileManager.default.removeItem(at: invalidDirectory)
            store.addCollection(name: "第二个收藏夹")
            await store.flushPendingSaves()
            await Task.yield()
            #expect(store.errorMessage == nil)
            let restored = ClipboardStore(directory: invalidDirectory, pasteboard: fixture.board, monitoring: false)
            #expect(restored.collections.count == 2)
        }
    }

    @Test("转换创建独立文本，保留原记录和收藏夹，清理 URL 不改变业务参数")
    func textTransformationsPreserveOriginal() async throws {
        try await withFixture { fixture in
            fixture.store.maxItems = 1
            fixture.record("  Hello Swift \n")
            let original = try #require(fixture.store.items.first)
            fixture.store.addCollection(name: "片段")
            let collection = try #require(fixture.store.collections.first)
            fixture.store.move(original, to: collection.id)
            let trimmed = try #require(fixture.store.transform(original, using: .trim))
            #expect(trimmed.text == "Hello Swift")
            #expect(trimmed.id != original.id)
            #expect(trimmed.collectionID == collection.id)
            #expect(fixture.store.items.first(where: { $0.id == original.id })?.text == original.text)
            #expect(fixture.store.maxItems == 2)
            let uppercase = try #require(fixture.store.transform(trimmed, using: .uppercase))
            #expect(uppercase.text == "HELLO SWIFT")
            let count = fixture.store.items.count
            #expect(fixture.store.transform(uppercase, using: .uppercase)?.id == uppercase.id)
            #expect(fixture.store.items.count == count)
            #expect(TextTransformation.lowercase.apply(to: "HELLO Swift") == "hello swift")
            #expect(TextTransformation.removeEmptyLines.apply(to: "first\r\n \t\nsecond\n\n") == "first\nsecond")
            let tracked = "https://example.com/search?q=a%20b&UTM_Source=email&key=x%2By&key=z&fbclid=123#result"
            #expect(TextTransformation.cleanURL.apply(to: tracked) == "https://example.com/search?q=a%20b&key=x%2By&key=z#result")
            #expect(TextTransformation.cleanURL.apply(to: "https://example.com/?utm_campaign=test") == "https://example.com/")
            #expect(TextTransformation.cleanURL.apply(to: "普通文本 utm_source=test") == "普通文本 utm_source=test")
        }
    }

    @Test("批量复制按选择顺序合并，批量移动删除与收藏夹改名保持引用一致")
    func batchOperationsAndCollectionRename() async throws {
        try await withFixture { fixture in
            let first = try #require(fixture.store.addText("第一条"))
            let second = try #require(fixture.store.addText("https://example.com"))
            let third = try #require(fixture.store.addText("第三条"))
            fixture.store.addCollection(name: "原名称")
            fixture.store.addCollection(name: "其他")
            let collection = try #require(fixture.store.collections.first)
            fixture.store.move(ids: [first.id, second.id], to: collection.id)
            #expect(fixture.store.renameCollection(collection, name: "  新名称  "))
            #expect(fixture.store.collections.first?.name == "新名称")
            #expect(fixture.store.collections.first?.id == collection.id)
            #expect(!fixture.store.renameCollection(collection, name: "其他"))
            #expect(!fixture.store.renameCollection(collection, name: "\n "))
            #expect(fixture.store.copyItems([second, first, second], separator: " | "))
            #expect(fixture.board.string(forType: .string) == "https://example.com | 第一条")
            #expect(fixture.store.items.map(\.id) == [second.id, first.id, third.id])
            #expect(fixture.store.items.filter { $0.collectionID == collection.id }.count == 2)
            #expect(!fixture.store.copyItems([first, ClipItem(text: "", kind: .image, imageData: Data([1]))]))
            #expect(fixture.board.string(forType: .string) == "https://example.com | 第一条")
            fixture.store.move(ids: [first.id], to: nil)
            #expect(fixture.store.items.first(where: { $0.id == first.id })?.collectionID == nil)
            fixture.store.delete(ids: [second.id, third.id])
            #expect(fixture.store.items.map(\.id) == [first.id])
        }
    }

    @Test("推迟重排的复制保持位置，应用后按最近使用排序")
    func deferredReorderKeepsPositionUntilApplied() async throws {
        try await withFixture { fixture in
            for text in ["一", "二", "三", "四"] { fixture.record(text) }
            let original = fixture.store.items
            #expect(original.map(\.text) == ["四", "三", "二", "一"])

            #expect(fixture.store.copy(original[2], reorder: false))
            #expect(fixture.board.string(forType: .string) == "二")
            #expect(fixture.store.items.map(\.text) == ["四", "三", "二", "一"])
            fixture.store.applyDeferredReorder()
            #expect(fixture.store.items.map(\.text) == ["二", "四", "三", "一"])

            #expect(fixture.store.copyItems([original[3], original[1]], reorder: false))
            #expect(fixture.board.string(forType: .string) == "一\n三")
            #expect(fixture.store.items.map(\.text) == ["二", "四", "三", "一"])
            fixture.store.applyDeferredReorder()
            #expect(fixture.store.items.map(\.text) == ["一", "三", "二", "四"])
        }
    }

    @Test("导入合并 UUID 和内容，映射同名收藏夹，保留本机记录和设置")
    func importMergesWithoutReplacingLocalData() async throws {
        try await withFixture { fixture in
            fixture.store.maxItems = 1
            fixture.store.excludedBundleIDs = "local.preference"
            let local = try #require(fixture.store.addText("本机编辑过的内容"))
            fixture.store.togglePin(local)
            fixture.store.addCollection(name: "工作")
            let localCollection = try #require(fixture.store.collections.first)
            fixture.store.move(local, to: localCollection.id)
            let importedCollection = ClipCollection(name: "工作")
            let otherCollection = ClipCollection(name: "资料")
            let incoming = ClipItem(text: "新导入", collectionID: importedCollection.id)
            let snapshot = TestSnapshot(items: [
                ClipItem(id: local.id, text: "备份中的旧内容"),
                ClipItem(text: local.text),
                incoming,
                ClipItem(text: incoming.text, collectionID: otherCollection.id)
            ], collections: [importedCollection, otherCollection], maxItems: 5, excludedBundleIDs: "imported.preference")
            let archiveURL = fixture.directory.appendingPathComponent("merge.json")
            try JSONEncoder().encode(snapshot).write(to: archiveURL)
            try await fixture.store.importHistory(from: archiveURL)
            #expect(fixture.store.items.count == 2)
            let preserved = try #require(fixture.store.items.first(where: { $0.id == local.id }))
            #expect(preserved.text == local.text)
            #expect(preserved.isPinned)
            #expect(preserved.collectionID == localCollection.id)
            #expect(fixture.store.items.first(where: { $0.id == incoming.id })?.collectionID == localCollection.id)
            #expect(fixture.store.collections.count == 2)
            #expect(fixture.store.excludedBundleIDs == "local.preference")
            #expect(fixture.store.maxItems == 2)
            try await fixture.store.importHistory(from: archiveURL)
            #expect(fixture.store.items.count == 2)
            #expect(fixture.store.lastAction?.contains("0 条记录") == true)
            let restored = ClipboardStore(directory: fixture.directory, pasteboard: fixture.board, monitoring: false)
            #expect(restored.items == fixture.store.items)
            #expect(restored.collections == fixture.store.collections)
        }
    }

    @Test("非法、超限和未知版本的导入不会部分修改现有数据")
    func invalidImportsAreAtomic() async throws {
        try await withFixture { fixture in
            let local = try #require(fixture.store.addText("始终保留"))
            fixture.store.addCollection(name: "本机")
            let originalCollections = fixture.store.collections
            let dangling = ClipItem(text: "无效引用", collectionID: UUID())
            let importedCollection = ClipCollection(name: "不应部分导入")
            let invalidSnapshots = [
                TestSnapshot(version: 2, items: [ClipItem(text: "不支持的版本")]),
                TestSnapshot(items: [dangling], collections: [importedCollection]),
                TestSnapshot(items: [local, local]),
                TestSnapshot(items: [ClipItem(text: "", kind: .image)]),
                TestSnapshot(collections: [ClipCollection(name: " ")]),
                TestSnapshot(items: [ClipItem(text: "文件", kind: .file, filePaths: ["../../file"])])
            ]
            let url = fixture.directory.appendingPathComponent("invalid.json")
            for snapshot in invalidSnapshots {
                try JSONEncoder().encode(snapshot).write(to: url)
                await #expect(throws: (any Error).self) { try await fixture.store.importHistory(from: url) }
                #expect(fixture.store.items == [local])
                #expect(fixture.store.collections == originalCollections)
                #expect(fixture.store.errorMessage?.hasPrefix("导入失败：") == true)
            }
            try Data("{ broken JSON".utf8).write(to: url)
            await #expect(throws: (any Error).self) { try await fixture.store.importHistory(from: url) }
            let oversized = try FileHandle(forWritingTo: url)
            try oversized.truncate(atOffset: UInt64(HistoryArchive.maximumFileBytes + 1))
            try oversized.close()
            await #expect(throws: HistoryError.self) { try await fixture.store.importHistory(from: url) }
            #expect(fixture.store.items == [local])
            #expect(fixture.store.collections == originalCollections)
        }
    }

    @Test("导出可重新导入，备份文件和历史仅对当前用户可读写")
    func exportRoundTripAndPrivatePermissions() async throws {
        try await withFixture { source in
            source.store.addText("导出内容")
            source.store.addCollection(name: "导出收藏夹")
            let item = try #require(source.store.items.first)
            let collection = try #require(source.store.collections.first)
            source.store.move(item, to: collection.id)
            let destination = source.directory.appendingPathComponent("backup.json")
            try await source.store.exportHistory(to: destination)
            let exported = try JSONDecoder().decode(HistorySnapshot.self, from: Data(contentsOf: destination))
            #expect(exported.items == source.store.items)
            #expect(exported.version == 1)
            let attributes = try FileManager.default.attributesOfItem(atPath: destination.path)
            #expect((attributes[.posixPermissions] as? NSNumber)?.intValue == 0o600)
            try await withFixture { target in
                try await target.store.importHistory(from: destination)
                #expect(target.store.items == source.store.items)
                #expect(target.store.collections == source.store.collections)
                let attributes = try FileManager.default.attributesOfItem(atPath: target.store.historyFileURL.path)
                #expect((attributes[.posixPermissions] as? NSNumber)?.intValue == 0o600)
            }
        }
    }

    @Test("导入后的磁盘失败会抛出错误且已有内存记录保留")
    func importReportsWriteFailure() async throws {
        try await withFixture { fixture in
            let blocked = fixture.directory.appendingPathComponent("blocked")
            try Data("file instead of directory".utf8).write(to: blocked)
            let store = ClipboardStore(directory: blocked, pasteboard: fixture.board, monitoring: false)
            let local = try #require(store.addText("已有内容"))
            let url = fixture.directory.appendingPathComponent("incoming.json")
            try JSONEncoder().encode(TestSnapshot(items: [ClipItem(text: "待导入")])).write(to: url)
            await #expect(throws: HistoryError.self) { try await store.importHistory(from: url) }
            #expect(store.items.contains(where: { $0.id == local.id }))
            #expect(store.errorMessage?.hasPrefix("导入失败：") == true)
            await store.flushPendingSaves()
        }
    }

    @Test("离线 Vision 识别真实渲染文字，损坏图片给出可见错误")
    func recognizesRenderedImageText() async throws {
        try await withFixture { fixture in
            let bitmap = try #require(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1_200, pixelsHigh: 220,
                                                       bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                                       isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
            let context = try #require(NSGraphicsContext(bitmapImageRep: bitmap))
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = context
            NSColor.white.setFill()
            NSRect(x: 0, y: 0, width: 1_200, height: 220).fill()
            ("PASTE HISTORY 2026" as NSString).draw(at: NSPoint(x: 45, y: 80), withAttributes: [
                .font: NSFont.systemFont(ofSize: 72, weight: .medium), .foregroundColor: NSColor.black
            ])
            NSGraphicsContext.restoreGraphicsState()
            let png = try #require(bitmap.representation(using: .png, properties: [:]))
            let recognized = try #require(await fixture.store.recognizeText(in: ClipItem(text: "", kind: .image, imageData: png)))
            #expect(recognized.contains("PASTE"))
            #expect(recognized.contains("HISTORY"))
            #expect(recognized.contains("2026"))
            #expect(fixture.store.items.isEmpty)
            #expect(await fixture.store.recognizeText(in: ClipItem(text: "", kind: .image, imageData: Data("broken image".utf8))) == nil)
            #expect(fixture.store.errorMessage?.hasPrefix("图片文字识别失败：") == true)
        }
    }
}

@MainActor
private final class ClipboardFixture {
    let directory: URL
    let board: NSPasteboard
    let store: ClipboardStore

    init(history: TestSnapshot? = nil, initialClipboard: String? = nil, monitoring: Bool = false) throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("XPastepalTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if let history {
            try JSONEncoder().encode(history).write(to: directory.appendingPathComponent("history.json"))
        }
        board = NSPasteboard(name: NSPasteboard.Name("XPastepalTests.\(UUID().uuidString)"))
        board.clearContents()
        if let initialClipboard { board.setString(initialClipboard, forType: .string) }
        store = ClipboardStore(directory: directory, pasteboard: board, monitoring: monitoring)
    }

    func record(_ text: String, app: String = "测试应用", bundleID: String = "com.example.test") {
        board.clearContents()
        board.setString(text, forType: .string)
        store.captureCurrentClipboard(sourceApp: app, sourceBundleID: bundleID)
    }

    func close() async {
        store.stopMonitoring(persistPreference: false)
        await store.flushPendingSaves()
        board.releaseGlobally()
        try? FileManager.default.removeItem(at: directory)
    }
}

@MainActor
private func withFixture(
    history: TestSnapshot? = nil,
    initialClipboard: String? = nil,
    monitoring: Bool = false,
    body: (ClipboardFixture) async throws -> Void
) async throws {
    let fixture = try ClipboardFixture(history: history, initialClipboard: initialClipboard, monitoring: monitoring)
    do {
        try await body(fixture)
        await fixture.close()
    } catch {
        await fixture.close()
        throw error
    }
}

private struct TestSnapshot: Encodable {
    var version = 1
    var items: [ClipItem] = []
    var collections: [ClipCollection] = []
    var maxItems = 500
    var excludedBundleIDs = ""
    var retentionDays = 0
}
