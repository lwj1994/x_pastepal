import AppKit
import SwiftUI
import Observation
import Carbon
import XPastepalCore

@main
struct XPastepalMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppCoordinator()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) { app.run() }
    }
}

@MainActor
@Observable
final class AppCoordinator: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let store: ClipboardStore
    let shortcuts: ShortcutService
    let panelPreferences: PanelPreferences
    var pasteMessage: String?
    /// 面板内短暂显示的提示，每次复制生成新 ID 以重新计时。
    private(set) var toast: PanelToast?
    var shortcutLabel: String { shortcuts.shortcutLabel }
    @ObservationIgnored private var mainWindow: NSWindow?
    @ObservationIgnored private var settingsWindow: NSWindow?
    @ObservationIgnored private var panel: QuickPanel?
    @ObservationIgnored private let panelTransition = PanelTransition()
    @ObservationIgnored private let escapeShortcut = PanelEscapeShortcut()
    @ObservationIgnored private var statusItem: NSStatusItem?
    @ObservationIgnored private var clickMonitor: Any?
    @ObservationIgnored private var pasteGeneration = 0
    @ObservationIgnored private var previousApp: NSRunningApplication?
    @ObservationIgnored private var localClickMonitor: Any?
    @ObservationIgnored private var activationObserver: NSObjectProtocol?

    override convenience init() {
        self.init(store: nil, shortcuts: ShortcutService(), panelPreferences: PanelPreferences())
    }

    init(store: ClipboardStore?, shortcuts: ShortcutService, panelPreferences: PanelPreferences) {
        self.shortcuts = shortcuts
        self.panelPreferences = panelPreferences
        if let store {
            self.store = store
        } else if ProcessInfo.processInfo.arguments.contains("--demo") {
            let board = NSPasteboard(name: .init("XPastepal.Demo.\(UUID().uuidString)"))
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent("XPastepal-Demo-\(UUID().uuidString)")
            self.store = ClipboardStore(directory: directory, pasteboard: board, monitoring: false)
            for (text, app) in [
                ("想法随手复制，灵感随时找回。\n\n一个安静的空间，装下每次值得保存的内容。", "备忘录"),
                ("https://developer.apple.com/swiftui/", "Safari"),
                ("let ideas = clipboard.history\n    .filter { $0.isWorthKeeping }\n    .sorted(by: mostRecent)", "Xcode"),
                ("周五的产品讨论\n\n• 优化快捷面板的键盘操作\n• 整理设计素材和常用链接\n• 留一点时间给新的想法", "备忘录"),
                ("#2DD4BF\n让界面多一点清新的绿。", "设计笔记")
            ] {
                board.clearContents()
                board.setString(text, forType: .string)
                self.store.captureCurrentClipboard(sourceApp: app, sourceBundleID: "demo.\(app)")
            }
            self.store.addCollection(name: "工作灵感")
            self.store.addCollection(name: "常用片段")
            if let item = self.store.items.first {
                self.store.togglePin(item)
                self.store.move(item, to: self.store.collections.first?.id)
            }
        } else { self.store = ClipboardStore() }
        super.init()
        escapeShortcut.onEscape = { [weak self] in self?.dismissPanel() }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureMenu()
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "square.on.square", accessibilityDescription: "XPastepal")
        item.button?.toolTip = "XPastepal · 剪贴板历史"
        item.button?.target = self
        item.button?.action = #selector(statusClicked(_:))
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusItem = item
        shortcuts.onTogglePanel = { [weak self] in self?.toggleQuickPanel() }
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] notification in
            MainActor.assumeIsolated {
                guard let self,
                      let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
                self.escapeShortcut.setEnabled(self.panelTransition.isPresented &&
                    app.processIdentifier != ProcessInfo.processInfo.processIdentifier)
            }
        }
        shortcuts.start()
        store.startBackgroundServices()
        if ProcessInfo.processInfo.arguments.contains("--quick-panel") { toggleQuickPanel() }
        else if !ProcessInfo.processInfo.arguments.contains("--background") { showLibrary() }
        // Prepare the hosting hierarchy before the first hotkey, outside the launch callback.
        RunLoop.main.perform(inModes: [.common]) { [weak self] in
            MainActor.assumeIsolated {
                guard let self, self.panel == nil, let screen = NSScreen.main else { return }
                self.preparePanel(in: screen)
            }
        }
    }

    private func configureMenu() {
        let main = NSMenu()
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu(title: "XPastepal")
        let preferences = NSMenuItem(title: "设置…", action: #selector(openSettings), keyEquivalent: ",")
        preferences.target = self
        appMenu.addItem(preferences)
        let quickItem = NSMenuItem(title: "打开快捷面板", action: #selector(openQuickPanel), keyEquivalent: "")
        quickItem.target = self
        appMenu.addItem(quickItem)
        appMenu.addItem(.separator())
        let quitItem = NSMenuItem(title: "退出 XPastepal", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        appMenu.addItem(quitItem)
        appMenuItem.submenu = appMenu
        main.addItem(appMenuItem)
        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: "编辑")
        for (title, selector, key) in [
            ("撤销", "undo:", "z"), ("剪切", "cut:", "x"),
            ("复制", "copy:", "c"), ("粘贴", "paste:", "v"), ("全选", "selectAll:", "a")
        ] {
            editMenu.addItem(NSMenuItem(title: title, action: Selector(selector), keyEquivalent: key))
        }
        editItem.submenu = editMenu
        main.addItem(editItem)
        NSApp.mainMenu = main
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if let panel, panelTransition.isPresented { panel.makeKeyAndOrderFront(nil) }
        else if !flag { toggleQuickPanel() }
        // 已自行选择要显示的窗口，不再让系统默认重开其他窗口。
        return false
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        shortcuts.stop()
        dismissPanel(animated: false)
        if let activationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(activationObserver)
            self.activationObserver = nil
        }
        store.stopMonitoring(persistPreference: false)
        store.stopBackgroundServices()
        Task { await store.flushPendingSaves(); NSApp.reply(toApplicationShouldTerminate: true) }
        return .terminateLater
    }

    @objc private func statusClicked(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            let menu = NSMenu()
            let items: [(String, Selector)] = [
                ("打开资料库", #selector(openLibrary)),
                (store.isMonitoring ? "暂停记录" : "继续记录", #selector(toggleMonitoring)),
                ("设置…", #selector(openSettings)),
                ("退出 XPastepal", #selector(quit))
            ]
            for (title, action) in items {
                let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
                item.target = self
                menu.addItem(item)
            }
            statusItem?.menu = menu
            sender.performClick(nil)
            statusItem?.menu = nil
        } else { toggleQuickPanel() }
    }

    @objc private func openLibrary() { showLibrary() }
    @objc private func openSettings() { showSettings() }
    @objc private func openQuickPanel() { toggleQuickPanel() }
    @objc private func toggleMonitoring() { store.isMonitoring ? store.stopMonitoring() : store.startMonitoring() }
    @objc private func quit() { NSApp.terminate(nil) }

    func showLibrary() {
        dismissPanel(animated: false)
        store.applyDeferredReorder()
        if mainWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1180, height: 760),
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
            window.title = ProcessInfo.processInfo.arguments.contains("--demo") ? "XPastepal · 演示" : "XPastepal"
            window.titlebarAppearsTransparent = true
            window.toolbar = NSToolbar(identifier: "LibraryToolbar")
            window.toolbarStyle = .unified
            window.minSize = NSSize(width: 1000, height: 620)
            window.isReleasedWhenClosed = false
            window.setFrameAutosaveName("XPastepal.Library")
            window.contentView = NSHostingView(rootView: LibraryView(store: store,
                onShowQuickPanel: { [weak self] in self?.toggleQuickPanel() },
                onShowSettings: { [weak self] in self?.showSettings() }))
            window.center()
            mainWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        mainWindow?.makeKeyAndOrderFront(nil)
    }

    func showSettings() {
        dismissPanel(animated: false)
        if settingsWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 600, height: 580),
                styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.title = "XPastepal 设置"
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: PreferencesView(coordinator: self, store: store))
            window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    func toggleQuickPanel() {
        if panelTransition.isPresented { dismissPanel(); return }
        let front = NSWorkspace.shared.frontmostApplication
        if front?.processIdentifier != ProcessInfo.processInfo.processIdentifier { previousApp = front }
        pasteMessage = nil
        toast = nil
        let screen = NSScreen.screens.first(where: { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) }) ?? NSScreen.main
        guard let screen else { return }
        // 面板内复制不会立即调整顺序，留到下次打开时再按最近使用排序。
        store.applyDeferredReorder()
        preparePanel(in: screen)
        // 先隐藏常规窗口，再交给面板接收键盘输入，避免资料库一起被带到前台。
        mainWindow?.orderOut(nil)
        settingsWindow?.orderOut(nil)
        NSApp.activate(ignoringOtherApps: true)
        if let panel {
            panelTransition.show(panel: panel, frame: panelFrame(in: screen), position: panelPreferences.position, screen: screen)
        }
        updateEscapeShortcut()
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, !self.panelPreferences.staysOpen else { return }
                self.dismissPanel()
            }
        }
        localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self, !self.panelPreferences.staysOpen, let panel = self.panel else { return event }
            // 弹出预览和菜单拥有独立窗口；只在点击资料库/设置时关闭面板。
            if event.window === self.mainWindow || event.window === self.settingsWindow {
                if event.window !== panel { self.dismissPanel() }
            }
            return event
        }
    }

    private func preparePanel(in screen: NSScreen) {
        if panel == nil {
            let window = QuickPanel(contentRect: panelFrame(in: screen), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            window.isFloatingPanel = true
            window.level = .floating
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = true
            window.hidesOnDeactivate = false
            window.isReleasedWhenClosed = false
            window.isMovable = false
            window.isMovableByWindowBackground = false
            window.animationBehavior = .none
            window.title = "XPastepal 快捷面板"
            window.onCancel = { [weak self] in self?.dismissPanel() }
            window.delegate = self
            window.contentView = PanelSurface(hostingView: NSHostingView(rootView: QuickPanelView(store: store, coordinator: self)))
            panel = window
            window.contentView?.layoutSubtreeIfNeeded()
        }
    }

    func windowDidBecomeKey(_ notification: Notification) { updateEscapeShortcut() }
    func windowDidResignKey(_ notification: Notification) { updateEscapeShortcut() }
    func applicationDidBecomeActive(_ notification: Notification) { updateEscapeShortcut() }
    func applicationDidResignActive(_ notification: Notification) {
        // A nonactivating panel can briefly retain its key-window flag after app deactivation.
        escapeShortcut.setEnabled(panelTransition.isPresented)
    }

    private func updateEscapeShortcut() {
        // Local responders retain Escape for IME composition, menus and previews.
        escapeShortcut.setEnabled(panelTransition.isPresented && panel?.isKeyWindow == false && !NSApp.isActive)
    }

    func positionPanel(in screen: NSScreen? = nil) {
        guard let panel, let screen = screen ?? panel.screen ?? NSScreen.main else { return }
        panelTransition.reposition(panel: panel, frame: panelFrame(in: screen), position: panelPreferences.position, screen: screen)
    }

    private func panelFrame(in screen: NSScreen) -> NSRect {
        let rect = screen.visibleFrame
        let height = min(360, rect.height)
        let frame: NSRect
        switch panelPreferences.position {
        case .bottom: frame = NSRect(x: rect.minX, y: rect.minY, width: rect.width, height: height)
        case .top: frame = NSRect(x: rect.minX, y: rect.maxY - height, width: rect.width, height: height)
        case .left: frame = NSRect(x: rect.minX, y: rect.minY, width: min(370, rect.width), height: rect.height)
        case .right: frame = NSRect(x: rect.maxX - min(370, rect.width), y: rect.minY, width: min(370, rect.width), height: rect.height)
        }
        return frame
    }

    func dismissPanel(animated: Bool = true) {
        escapeShortcut.setEnabled(false)
        if let panel { panelTransition.hide(panel: panel, animated: animated) }
        if let clickMonitor { NSEvent.removeMonitor(clickMonitor); self.clickMonitor = nil }
        if let localClickMonitor { NSEvent.removeMonitor(localClickMonitor); self.localClickMonitor = nil }
    }

    func pasteItems(_ items: [ClipItem], plainText: Bool = false) {
        guard !items.isEmpty else { return }
        if items.count == 1, let item = items.first { paste(item, plainText: plainText); return }
        guard copyItems(items) else { return }
        finishPaste()
    }

    func paste(_ item: ClipItem, plainText: Bool = false) {
        let usePlainText = plainText || (panelPreferences.plainTextByDefault && (item.kind == .text || item.kind == .link))
        guard copy(item, plainText: usePlainText) else { return }
        finishPaste()
    }

    /// 面板内仅复制：写入剪贴板并提示，不粘贴。
    @discardableResult
    func copy(_ item: ClipItem, plainText: Bool = false) -> Bool {
        guard store.copy(item, plainText: plainText, reorder: false) else { pasteMessage = store.errorMessage; return false }
        showToast("已复制")
        return true
    }

    @discardableResult
    func copyItems(_ items: [ClipItem]) -> Bool {
        guard store.copyItems(items, reorder: false) else { pasteMessage = store.errorMessage; return false }
        showToast(items.count > 1 ? "已复制 \(items.count) 项" : "已复制")
        return true
    }

    private func showToast(_ message: String) {
        let current = PanelToast(message: message)
        toast = current
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(1.2))
            if self?.toast?.id == current.id { self?.toast = nil }
        }
    }

    private func finishPaste() {
        pasteGeneration += 1
        let generation = pasteGeneration
        if panelPreferences.copyOnly {
            pasteMessage = "已复制到剪贴板。"
            if !panelPreferences.staysOpen { dismissPanel() }
            return
        }
        if ProcessInfo.processInfo.arguments.contains("--demo") {
            pasteMessage = "演示模式：已复制到独立测试剪贴板。"
            return
        }
        guard PermissionAccess.isAccessibilityGranted else {
            pasteMessage = "已复制。按 ⌘V 粘贴，或在设置中启用辅助功能以自动粘贴。"
            return
        }
        guard let target = previousApp, !target.isTerminated else {
            pasteMessage = "已复制到剪贴板；请切换到目标应用并按 ⌘V。"
            return
        }
        if !panelPreferences.staysOpen { dismissPanel(animated: false) }
        target.activate(options: [])
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(180))
            guard generation == pasteGeneration else { return }
            guard NSWorkspace.shared.frontmostApplication?.processIdentifier == target.processIdentifier else {
                store.lastAction = "已复制，目标应用未激活，请手动粘贴"
                return
            }
            let source = CGEventSource(stateID: .combinedSessionState)
            let down = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true)
            let up = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false)
            down?.flags = .maskCommand
            up?.flags = .maskCommand
            down?.post(tap: .cghidEventTap)
            up?.post(tap: .cghidEventTap)
        }
    }


}

struct PanelToast: Equatable {
    let id = UUID()
    let message: String
}

class QuickPanel: NSPanel {
    var onCancel: (() -> Void)?
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    // The coordinator owns docking geometry, including frames at the screen edges.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }

    // 搜索控件将 Esc 交给原生响应链时，也能收起固定面板。
    override func cancelOperation(_ sender: Any?) { onCancel?() }
}

/// A stable layer outside SwiftUI's managed layer tree owns the slide animation.
final class PanelSurface: NSView {
    init(hostingView: NSView) {
        super.init(frame: hostingView.frame)
        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay
        hostingView.frame = bounds
        hostingView.autoresizingMask = [.width, .height]
        addSubview(hostingView)
    }

    required init?(coder: NSCoder) { nil }
}
