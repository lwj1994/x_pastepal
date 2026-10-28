import Foundation
import Observation

/// 粘贴队列：短时间内连续复制的内容按复制顺序自动排队，剪贴板始终放着队首，每次粘贴后前进一项。
/// 两次复制间隔超过 `burstInterval`，或其间粘贴过，都视为普通复制，不排队。
@MainActor
@Observable
public final class PasteQueue {
    public enum PasteOutcome: Equatable {
        /// 没有排队中的内容，未做处理。
        case ignored
        /// 已粘贴队首，剪贴板换成下一项。
        case advanced
        /// 粘贴的是其他内容，队首重新放回剪贴板。
        case restaged
        /// 最后一项已粘贴，队列结束。
        case finished
    }

    public private(set) var itemIDs: [UUID] = []
    public var isActive: Bool { !itemIDs.isEmpty }
    public var count: Int { itemIDs.count }
    public var nextItem: ClipItem? { itemIDs.lazy.compactMap(item(for:)).first }
    @ObservationIgnored public var burstInterval: TimeInterval = 10
    /// 决定写入剪贴板时是否只保留纯文本。
    @ObservationIgnored public var prefersPlainText: (ClipItem) -> Bool = { _ in false }

    @ObservationIgnored private let store: ClipboardStore
    @ObservationIgnored private var lastCapture: (id: UUID, date: Date)?
    @ObservationIgnored private var stagedID: UUID?
    @ObservationIgnored private var stagedChangeCount: Int?

    public init(store: ClipboardStore) {
        self.store = store
    }

    /// 每次采集到用户复制的新内容后调用，`item` 此时就在剪贴板上。
    public func didCapture(_ item: ClipItem, at date: Date = Date()) {
        defer { lastCapture = (item.id, date) }
        guard let last = lastCapture, date.timeIntervalSince(last.date) <= burstInterval else {
            clearItems()
            return
        }
        // 重复复制同一内容不新增，只把队首放回剪贴板。
        guard item.id != last.id else {
            if isActive { stageNext() }
            return
        }
        if !isActive {
            guard self.item(for: last.id) != nil else { return }
            itemIDs = [last.id]
        }
        itemIDs.append(item.id)
        stageNext()
    }

    /// 目标应用处理完一次粘贴后调用；`changeCount` 为按下粘贴键时的剪贴板版本号。
    /// 粘贴会打断连续复制，之后的复制重新计算。
    @discardableResult
    public func didPaste(changeCount: Int) -> PasteOutcome {
        lastCapture = nil
        guard isActive else { return .ignored }
        guard changeCount == stagedChangeCount, stagedID == itemIDs.first else {
            stageNext()
            return isActive ? .restaged : .finished
        }
        itemIDs.removeFirst()
        stagedID = nil
        stagedChangeCount = nil
        guard isActive else { return .finished }
        stageNext()
        return isActive ? .advanced : .finished
    }

    /// 结束队列并忘记上一次复制，剪贴板保持当前内容。
    public func stop() {
        clearItems()
        lastCapture = nil
    }

    private func clearItems() {
        itemIDs = []
        stagedID = nil
        stagedChangeCount = nil
    }

    /// 把队首写入剪贴板，跳过已从历史删除或无法写入的条目；取空时结束队列。
    private func stageNext() {
        while let id = itemIDs.first {
            guard let item = item(for: id) else { itemIDs.removeFirst(); continue }
            if stagedID == id, stagedChangeCount == store.pasteboardChangeCount { return }
            if store.copy(item, plainText: prefersPlainText(item), reorder: false) {
                stagedID = id
                stagedChangeCount = store.pasteboardChangeCount
                return
            }
            itemIDs.removeFirst()
        }
        clearItems()
    }

    private func item(for id: UUID) -> ClipItem? {
        store.items.first { $0.id == id }
    }
}
