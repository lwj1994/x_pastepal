import AppKit
import Foundation
import Testing
@testable import XPastepalCore

@Suite(.serialized)
@MainActor
struct PasteQueueTests {
    @Test("短时间连续复制自动排队，剪贴板保持队首，每次粘贴吐出下一项")
    func pastesInCopyOrder() async throws {
        try await withQueueFixture { fixture in
            fixture.record("第一段")
            #expect(!fixture.queue.isActive)
            #expect(fixture.clipboard == "第一段")

            fixture.record("第二段", after: 2)
            fixture.record("第三段", after: 2)
            #expect(fixture.queue.count == 3)
            #expect(fixture.clipboard == "第一段")
            #expect(fixture.queue.nextItem?.text == "第一段")

            #expect(fixture.paste() == .advanced)
            #expect(fixture.clipboard == "第二段")
            #expect(fixture.paste() == .advanced)
            #expect(fixture.clipboard == "第三段")
            #expect(fixture.paste() == .finished)
            #expect(!fixture.queue.isActive)
            #expect(fixture.clipboard == "第三段")
            #expect(fixture.paste() == .ignored)
        }
    }

    @Test("间隔过长或中间粘贴过的复制不排队")
    func ordinaryCopiesDoNotQueue() async throws {
        try await withQueueFixture { fixture in
            fixture.record("A")
            fixture.record("B", after: 11)
            #expect(!fixture.queue.isActive)
            #expect(fixture.clipboard == "B")

            // 复制、粘贴交替进行时保持普通行为。
            #expect(fixture.paste() == .ignored)
            fixture.record("C", after: 1)
            #expect(!fixture.queue.isActive)
            #expect(fixture.clipboard == "C")
        }
    }

    @Test("粘贴后再复制会放弃剩余队列，从新的复制重新开始")
    func copyAfterPasteResetsQueue() async throws {
        try await withQueueFixture { fixture in
            fixture.record("一")
            fixture.record("二", after: 1)
            fixture.record("三", after: 1)
            #expect(fixture.paste() == .advanced)

            fixture.record("新的", after: 1)
            #expect(!fixture.queue.isActive)
            #expect(fixture.clipboard == "新的")
            fixture.record("更新的", after: 1)
            #expect(fixture.queue.count == 2)
            #expect(fixture.clipboard == "新的")
        }
    }

    @Test("重复复制同一内容不新增；不相邻的重复内容会再次排队")
    func duplicates() async throws {
        try await withQueueFixture { fixture in
            fixture.record("A")
            fixture.record("A", after: 1)
            #expect(!fixture.queue.isActive)

            fixture.record("B", after: 1)
            fixture.record("B", after: 1)
            #expect(fixture.queue.count == 2)
            #expect(fixture.clipboard == "A")

            fixture.record("A", after: 1)
            #expect(fixture.queue.count == 3)
            #expect(fixture.paste() == .advanced)
            #expect(fixture.clipboard == "B")
            #expect(fixture.paste() == .advanced)
            #expect(fixture.clipboard == "A")
        }
    }

    @Test("粘贴的不是队首时不前进，并把队首放回剪贴板")
    func restagesAfterForeignPaste() async throws {
        try await withQueueFixture { fixture in
            fixture.record("队首")
            fixture.record("第二项", after: 1)
            let other = try #require(fixture.store.items.first { $0.text == "第二项" })
            // 例如在资料库中直接复制了其他条目再粘贴。
            #expect(fixture.store.copy(other, reorder: false))

            #expect(fixture.paste() == .restaged)
            #expect(fixture.queue.count == 2)
            #expect(fixture.clipboard == "队首")
            #expect(fixture.paste() == .advanced)
            #expect(fixture.clipboard == "第二项")
        }
    }

    @Test("从历史删除的条目会被跳过，删空后结束")
    func skipsDeletedItems() async throws {
        try await withQueueFixture { fixture in
            fixture.record("一")
            fixture.record("二", after: 1)
            fixture.record("三", after: 1)
            fixture.store.delete(try #require(fixture.store.items.first { $0.text == "二" }))

            #expect(fixture.paste() == .advanced)
            #expect(fixture.clipboard == "三")
            #expect(fixture.queue.count == 1)

            fixture.store.delete(try #require(fixture.store.items.first { $0.text == "三" }))
            #expect(fixture.paste() == .finished)
            #expect(!fixture.queue.isActive)
        }
    }

    @Test("结束队列后剪贴板保持当前内容，下一次复制不与之前的连起来")
    func stopKeepsClipboard() async throws {
        try await withQueueFixture { fixture in
            fixture.record("甲")
            fixture.record("乙", after: 1)
            fixture.queue.stop()
            #expect(!fixture.queue.isActive)
            #expect(fixture.clipboard == "甲")

            fixture.record("丙", after: 1)
            #expect(!fixture.queue.isActive)
            #expect(fixture.clipboard == "丙")
        }
    }

    @Test("轮询前的复制可立即采集并加入队列")
    func captureIfChangedBeforePolling() async throws {
        try await withQueueFixture(monitoring: true) { fixture in
            fixture.record("先复制")
            fixture.board.clearContents()
            fixture.board.setString("刚复制", forType: .string)
            fixture.store.captureIfChanged()
            #expect(fixture.queue.count == 2)
            #expect(fixture.store.items.contains { $0.text == "刚复制" })
            #expect(fixture.clipboard == "先复制")
        }
    }

    @Test("纯文本偏好只写入文字，不带富文本")
    func plainTextPreference() async throws {
        try await withQueueFixture { fixture in
            fixture.queue.prefersPlainText = { _ in true }
            let rtf = try NSAttributedString(string: "富文本").data(
                from: NSRange(location: 0, length: 3), documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
            fixture.board.clearContents()
            fixture.board.setString("富文本", forType: .string)
            fixture.board.setData(rtf, forType: .rtf)
            fixture.store.captureCurrentClipboard(sourceApp: "测试应用", sourceBundleID: "com.example.test")
            fixture.record("第二项", after: 1)

            #expect(fixture.clipboard == "富文本")
            #expect(fixture.board.data(forType: .rtf) == nil)
        }
    }
}

@MainActor
private final class QueueFixture {
    let directory: URL
    let board: NSPasteboard
    let store: ClipboardStore
    let queue: PasteQueue
    /// 模拟时钟，按秒推进复制时间。
    private(set) var now = Date()

    init(monitoring: Bool) throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("XPastepalQueueTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        board = NSPasteboard(name: NSPasteboard.Name("XPastepalQueueTests.\(UUID().uuidString)"))
        board.clearContents()
        store = ClipboardStore(directory: directory, pasteboard: board, monitoring: monitoring)
        queue = PasteQueue(store: store)
        store.onCapture = { [unowned self] item in self.queue.didCapture(item, at: self.now) }
    }

    var clipboard: String? { board.string(forType: .string) }

    func record(_ text: String, after seconds: TimeInterval = 0) {
        now = now.addingTimeInterval(seconds)
        board.clearContents()
        board.setString(text, forType: .string)
        store.captureCurrentClipboard(sourceApp: "测试应用", sourceBundleID: "com.example.test")
    }

    /// 模拟目标应用读取剪贴板后的回调。
    func paste() -> PasteQueue.PasteOutcome {
        queue.didPaste(changeCount: board.changeCount)
    }

    func close() async {
        queue.stop()
        store.stopMonitoring(persistPreference: false)
        await store.flushPendingSaves()
        board.releaseGlobally()
        try? FileManager.default.removeItem(at: directory)
    }
}

@MainActor
private func withQueueFixture(monitoring: Bool = false, _ body: (QueueFixture) async throws -> Void) async throws {
    let fixture = try QueueFixture(monitoring: monitoring)
    do {
        try await body(fixture)
        await fixture.close()
    } catch {
        await fixture.close()
        throw error
    }
}
