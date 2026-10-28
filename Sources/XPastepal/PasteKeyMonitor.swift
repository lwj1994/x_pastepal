import AppKit
import ApplicationServices
import Carbon

/// 监听其他应用中的 ⌘V，供粘贴队列在每次粘贴后前进；全局按键监听需要辅助功能权限。
/// 松开 V 后再稍等片刻才通知，确保目标应用已经读完剪贴板。
@MainActor
final class PasteKeyMonitor {
    /// 参数为按下粘贴键时的剪贴板版本号。
    var onPaste: ((Int) -> Void)?
    /// 按下粘贴键时调用，返回此刻的剪贴板版本号。
    private let pasteKeyDown: () -> Int
    private var monitor: Any?
    private var isTrusted = false
    private var pending: (keyCode: UInt16, changeCount: Int)?
    private var pendingTask: Task<Void, Never>?

    var isRunning: Bool { monitor != nil }

    init(pasteKeyDown: @escaping () -> Int) {
        self.pasteKeyDown = pasteKeyDown
    }

    func start() {
        stop()
        isTrusted = AXIsProcessTrusted()
        monitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
            MainActor.assumeIsolated { self?.handle(event) }
        }
    }

    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        pendingTask?.cancel()
        pendingTask = nil
        pending = nil
    }

    /// 授权前注册的监听收不到按键，获得权限后重新注册。
    func restartIfNewlyTrusted() {
        if monitor != nil, !isTrusted, AXIsProcessTrusted() { start() }
    }

    static func isPasteKey(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard flags.contains(.command), !flags.contains(.control) else { return false }
        guard let character = event.charactersIgnoringModifiers?.lowercased(), !character.isEmpty else { return false }
        // 非拉丁键盘布局下按物理键位识别。
        return character == "v" || (!character.allSatisfy(\.isASCII) && Int(event.keyCode) == kVK_ANSI_V)
    }

    private func handle(_ event: NSEvent) {
        switch event.type {
        case .keyDown:
            guard !event.isARepeat, Self.isPasteKey(event) else { return }
            // 上一次粘贴尚未结算时先结算，避免连续粘贴丢失前进。
            finishPending()
            pending = (event.keyCode, pasteKeyDown())
            // 收不到松键事件时兜底。
            schedule(after: .milliseconds(800))
        case .keyUp:
            guard let pending, event.keyCode == pending.keyCode else { return }
            schedule(after: .milliseconds(100))
        default:
            break
        }
    }

    private func schedule(after delay: Duration) {
        pendingTask?.cancel()
        pendingTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            self?.finishPending()
        }
    }

    private func finishPending() {
        pendingTask?.cancel()
        pendingTask = nil
        guard let pending else { return }
        self.pending = nil
        onPaste?(pending.changeCount)
    }
}
