import AppKit
import KeyboardShortcuts
import Observation

extension KeyboardShortcuts.Name {
    static let toggleQuickPanel = Self("toggleQuickPanel", initial: .init(.v, modifiers: [.option, .command]))
}

/// 全局快捷键只有一个事件入口，菜单和面板不再额外注册同一组合。
@MainActor
@Observable
final class ShortcutService {
    private(set) var shortcutLabel = "未设置"
    private(set) var statusMessage: String?
    private(set) var isEnabled = false
    private(set) var hasShortcut = false
    private(set) var isDefaultShortcut = false

    @ObservationIgnored var onTogglePanel: (() -> Void)?
    @ObservationIgnored let name: KeyboardShortcuts.Name
    @ObservationIgnored private var isStarted = false

    /// 可注入独立名称与旧偏好域，测试不会读取或修改用户快捷键。
    init(nameRawValue: String = "toggleQuickPanel", legacyDefaults: UserDefaults = .standard) {
        // Name(initial:) 会立即写入默认值，因此必须先检查存储。
        // 显式清除也属于已保存偏好，不能在下次启动时被默认值覆盖。
        let alreadyStored = KeyboardShortcuts.storedNames.contains { $0.rawValue == nameRawValue }
        name = nameRawValue == "toggleQuickPanel"
            ? .toggleQuickPanel
            : KeyboardShortcuts.Name(nameRawValue, initial: Self.defaultShortcut)
        if !alreadyStored, let legacyMode = legacyDefaults.object(forKey: "shortcutMode") as? Int {
            let migrated = legacyMode == 1
                ? KeyboardShortcuts.Shortcut(.v, modifiers: [.control, .shift])
                : Self.defaultShortcut
            KeyboardShortcuts.setShortcut(migrated, for: name)
        }
        refreshStatus()
    }

    static var defaultShortcut: KeyboardShortcuts.Shortcut {
        .init(.v, modifiers: [.option, .command])
    }

    func start() {
        guard !isStarted else { return }
        isStarted = true
        // 显式替换同名回调，防止重新启动服务后一次按键触发两次。
        KeyboardShortcuts.removeHandler(for: name)
        KeyboardShortcuts.enable(name)
        KeyboardShortcuts.onKeyDown(for: name) { [weak self] in
            self?.onTogglePanel?()
        }
        refreshStatus()
    }

    func stop() {
        KeyboardShortcuts.removeHandler(for: name)
        KeyboardShortcuts.disable(name)
        isStarted = false
        refreshStatus()
    }

    func clear() {
        KeyboardShortcuts.setShortcut(nil, for: name)
        refreshStatus()
    }

    func resetToDefault() {
        KeyboardShortcuts.reset(name)
        refreshStatus()
    }

    func retryRegistration() {
        stop()
        start()
    }

    func refreshStatus() {
        let shortcut = KeyboardShortcuts.getShortcut(for: name)
        shortcutLabel = shortcut.map(String.init(describing:)) ?? "未设置"
        hasShortcut = shortcut != nil
        isDefaultShortcut = shortcut == Self.defaultShortcut
        isEnabled = isStarted && KeyboardShortcuts.isEnabled(for: name)

        if let shortcut, shortcut.isTakenBySystem {
            statusMessage = "\(shortcut) 与 macOS 系统快捷键冲突，请录制其他组合，或前往系统设置更改快捷键。"
        } else if shortcut != nil, isStarted, !isEnabled {
            statusMessage = "\(shortcutLabel) 注册失败，可能已被 PastePal 或其他应用占用。请更换组合，或在关闭冲突应用后重试。"
        } else {
            statusMessage = nil
        }
    }
}
