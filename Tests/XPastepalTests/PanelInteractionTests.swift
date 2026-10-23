import AppKit
import Carbon
import KeyboardShortcuts
import QuartzCore
import SwiftUI
import Testing
@testable import XPastepal
@testable import XPastepalCore

@Suite(.serialized)
@MainActor
struct PanelInteractionTests {
    @Test("Global Escape is temporary, idempotent and released on dismissal")
    func globalEscapeLifecycle() throws {
        let shortcut = PanelEscapeShortcut()
        var dismissals = 0
        shortcut.onEscape = {
            dismissals += 1
            shortcut.setEnabled(false)
        }
        defer { shortcut.onEscape = nil; shortcut.setEnabled(false) }

        shortcut.setEnabled(true)
        shortcut.setEnabled(true)
        #expect(shortcut.isEnabled)
        #expect(!canReserveEscape())
        try sendHotKey(id: EventHotKeyID(signature: 0x58504553, id: 99))
        #expect(dismissals == 0)
        try sendHotKey(id: EventHotKeyID(signature: 0x58504553, id: 1))
        #expect(dismissals == 1)
        #expect(!shortcut.isEnabled)
        #expect(canReserveEscape())

        try sendHotKey(id: EventHotKeyID(signature: 0x58504553, id: 1))
        #expect(dismissals == 1)
        shortcut.setEnabled(true)
        try sendHotKey(id: EventHotKeyID(signature: 0x58504553, id: 1))
        #expect(dismissals == 2)
        #expect(canReserveEscape())
    }

    @Test("Escape registration is released when its owner goes away")
    func escapeCleanup() {
        var shortcut: PanelEscapeShortcut? = PanelEscapeShortcut()
        shortcut?.setEnabled(true)
        #expect(!canReserveEscape())
        shortcut = nil
        #expect(canReserveEscape())
    }

    @Test("Compositor transitions finish at each edge and can reverse")
    func transitionLifecycle() async throws {
        _ = NSApplication.shared
        let screen = try #require(NSScreen.main)
        let panel = QuickPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                               backing: .buffered, defer: false)
        panel.isReleasedWhenClosed = false
        let transition = PanelTransition()
        defer { transition.hide(panel: panel, animated: false) }

        for position in PanelPosition.allCases {
            let frame = frame(at: position, on: screen)
            transition.show(panel: panel, frame: frame, position: position, screen: screen)
            #expect(transition.isPresented)
            try await waitUntil { !transition.isAnimating && panel.frame == frame }
            #expect(panel.isVisible)
            #expect(CATransform3DIsIdentity(try #require(panel.contentView?.layer).transform))

            transition.hide(panel: panel)
            #expect(!transition.isPresented)
            try await Task.sleep(for: .milliseconds(50))
            transition.show(panel: panel, frame: frame, position: position, screen: screen)
            try await waitUntil { !transition.isAnimating && panel.frame == frame }
            // An obsolete closing callback must not hide a reopened panel.
            try await Task.sleep(for: .milliseconds(250))
            #expect(panel.isVisible)
            #expect(transition.isPresented)
            transition.hide(panel: panel)
            try await waitUntil { !panel.isVisible }
        }
    }

    @Test("Changing edges and interrupting an animation keep the latest destination")
    func interruptedReposition() async throws {
        _ = NSApplication.shared
        let screen = try #require(NSScreen.main)
        let panel = QuickPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                               backing: .buffered, defer: false)
        panel.isReleasedWhenClosed = false
        let transition = PanelTransition()
        defer { transition.hide(panel: panel, animated: false) }
        let bottom = frame(at: .bottom, on: screen)
        let right = frame(at: .right, on: screen)
        transition.show(panel: panel, frame: bottom, position: .bottom, screen: screen)
        transition.finish(panel: panel)
        transition.reposition(panel: panel, frame: right, position: .right, screen: screen)
        try await waitUntil { !transition.isAnimating && panel.frame == right }
        transition.reposition(panel: panel, frame: bottom, position: .bottom, screen: screen)
        transition.hide(panel: panel, animated: false)
        try await Task.sleep(for: .milliseconds(450))
        #expect(!panel.isVisible)
        #expect(!transition.isPresented)
        transition.show(panel: panel, frame: right, position: .right, screen: screen)
        transition.finish(panel: panel)
        #expect(panel.frame == right)
        #expect(panel.isVisible)
    }

    @Test("Repeated presentation reuses the hosting view with a populated history")
    func reusesPanelContent() async throws {
        try await withPopulatedCoordinator { coordinator in
            coordinator.toggleQuickPanel()
            let panel = try #require(NSApp.windows.compactMap { $0 as? QuickPanel }
                .first { $0.title == "XPastepal 快捷面板" })
            let content = try #require(panel.contentView)
            try await Task.sleep(for: .milliseconds(300))
            coordinator.dismissPanel(animated: false)
            coordinator.toggleQuickPanel()
            #expect(panel.contentView === content)
            #expect(panel.isVisible)
            coordinator.dismissPanel(animated: false)
        }
    }

    @Test("App deactivation enables Escape even before the panel's key state catches up")
    func deactivationDismissesPanel() async throws {
        try await withPopulatedCoordinator { coordinator in
            coordinator.panelPreferences.staysOpen = true
            coordinator.toggleQuickPanel()
            let panel = try #require(NSApp.windows.compactMap { $0 as? QuickPanel }
                .first { $0.title == "XPastepal 快捷面板" && $0.isVisible })
            coordinator.applicationDidResignActive(Notification(name: NSApplication.didResignActiveNotification))
            #expect(!canReserveEscape())
            try sendHotKey(id: EventHotKeyID(signature: 0x58504553, id: 1))
            #expect(canReserveEscape())
            try await waitUntil { !panel.isVisible }
        }
    }

    @Test("Card thumbnails are bounded, cached and invalidated when image content changes")
    func thumbnailCache() async throws {
        try await withPopulatedCoordinator { coordinator in
            let item = try #require(coordinator.store.items.first { $0.kind == .image })
            let data = try #require(item.imageData)
            let cache = ClipThumbnailCache()
            let thumbnail = try #require(await cache.image(for: item.id, source: .data(data)))
            #expect(thumbnail.width <= 640)
            #expect(thumbnail.height <= 640)
            let cached = await cache.image(for: item.id, source: .data(data))
            #expect(cached === thumbnail)
            // A reused UUID with corrupt/new data must not return an obsolete image.
            #expect(await cache.image(for: item.id, source: .data(Data("invalid image".utf8))) == nil)

            let url = coordinator.store.directory.appendingPathComponent("test.png")
            try data.write(to: url, options: .atomic)
            let fileItem = ClipItem(text: "", kind: .file, filePaths: [url.path])
            let source = try #require(fileItem.imagePreviewSource)
            #expect(source == .file(url))
            #expect(ClipImageSource.imageFile(at: "/tmp/document.txt") == nil)
            let fileThumbnail = try #require(await cache.image(for: fileItem.id, source: source))
            #expect(fileThumbnail.width == thumbnail.width)
            #expect(await cache.image(for: fileItem.id, source: source) === fileThumbnail)
            let preview = try #require(await cache.image(for: fileItem.id, source: source, maximumPixelSize: 1600))
            #expect(preview.width == 1600)
            try Data("replaced file".utf8).write(to: url, options: .atomic)
            #expect(await cache.image(for: fileItem.id, source: source) == nil)
            try FileManager.default.removeItem(at: url)
            #expect(await cache.image(for: fileItem.id, source: source) == nil)
        }
    }

    @Test("Wide and tall images fill their cards without covering adjacent cards",
          arguments: [false, true], [CGSize(width: 320, height: 160), CGSize(width: 1600, height: 80), CGSize(width: 80, height: 1600)])
    func rendersImageCard(asFile: Bool, imageSize: CGSize) async throws {
        _ = NSApplication.shared
        let bitmap = try #require(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(imageSize.width), pixelsHigh: Int(imageSize.height),
                                                  bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                                  isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        let pixels = try #require(bitmap.bitmapData)
        for y in 0..<bitmap.pixelsHigh {
            for x in 0..<bitmap.pixelsWide {
                let offset = y * bitmap.bytesPerRow + x * 4
                pixels[offset] = 240; pixels[offset + 1] = 20
                pixels[offset + 2] = 30; pixels[offset + 3] = 255
            }
        }
        let data = try #require(bitmap.representation(using: asFile ? .jpeg : .png, properties: [:]))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("XPastepal-Image-\(UUID()).jpg")
        if asFile { try data.write(to: url) }
        defer { if asFile { try? FileManager.default.removeItem(at: url) } }
        let item = ClipItem(text: "", kind: asFile ? .file : .image, sourceApp: "Image fixture",
                            filePaths: asFile ? [url.path] : [], imageData: asFile ? nil : data)
        let view = NSHostingView(rootView: HStack(spacing: 12) {
            ForEach(0..<2) { _ in
                ClipCard(item: item, isSelected: false, onSelect: {}, onCopy: {}, aspectRatio: 228.0 / 190.0)
                    .frame(width: 228, height: 190)
            }
        }.background(Color.green))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 468, height: 190),
                              styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = view
        window.orderFront(nil)
        defer { window.orderOut(nil); window.contentView = nil }
        var rendered = false
        let deadline = Date().addingTimeInterval(2)
        repeat {
            try await Task.sleep(for: .milliseconds(100))
            view.layoutSubtreeIfNeeded()
            view.displayIfNeeded()
            let snapshot = try #require(view.bitmapImageRepForCachingDisplay(in: view.bounds))
            view.cacheDisplay(in: view.bounds, to: snapshot)
            func colorAt(_ x: Int, _ y: Int) -> NSColor? {
                snapshot.colorAt(x: x * snapshot.pixelsWide / 468, y: y * snapshot.pixelsHigh / 190)?
                    .usingColorSpace(.deviceRGB)
            }
            // Sample both sides of both previews: neither aspect-fit letterboxing nor
            // a neighboring card may cover the image. The 12-point gap must stay clear.
            rendered = [20, 208, 260, 448].allSatisfy { x in
                [65, 120].allSatisfy { y in
                    colorAt(x, y).map {
                        $0.redComponent > 0.7 && $0.redComponent > $0.greenComponent + 0.4 &&
                            $0.redComponent > $0.blueComponent + 0.4
                    } ?? false
                }
            }
            rendered = rendered && (colorAt(234, 95).map {
                $0.greenComponent > $0.redComponent + 0.2 && $0.greenComponent > $0.blueComponent + 0.2
            } ?? false)
        } while !rendered && Date() < deadline
        #expect(rendered, "Both previews must fill their bounds while the gap between cards stays visible.")
    }

    @Test("Profile compositor submission with 200 cards including 4K images",
          .enabled(if: ProcessInfo.processInfo.environment["XPASTEPAL_PROFILE_PANEL"] == "1"))
    func profilePanelFrames() async throws {
        try await withPopulatedCoordinator { coordinator in
            let screen = try #require(NSScreen.main)
            let frame = NSRect(x: screen.visibleFrame.minX, y: screen.visibleFrame.minY,
                               width: screen.visibleFrame.width, height: 360)
            let panel = FrameRecordingPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel],
                                            backing: .buffered, defer: false)
            panel.isReleasedWhenClosed = false
            panel.contentView = PanelSurface(hostingView: NSHostingView(rootView: QuickPanelView(store: coordinator.store, coordinator: coordinator)))
            panel.contentView?.layoutSubtreeIfNeeded()
            let transition = PanelTransition()
            defer { transition.hide(panel: panel, animated: false) }
            for run in 1...5 {
                panel.frameTimes = []
                let started = CACurrentMediaTime()
                transition.show(panel: panel, frame: frame, position: .bottom, screen: screen)
                let submitted = CACurrentMediaTime()
                try await waitUntil { !transition.isAnimating && panel.frame == frame }
                #expect(panel.frameTimes.isEmpty)
                print(String(format: "Panel run %d: submitted %.1f ms, per-frame window moves %d",
                             run, (submitted - started) * 1_000, panel.frameTimes.count))
                transition.hide(panel: panel, animated: false)
            }
        }
    }

    private func withPopulatedCoordinator(_ body: (AppCoordinator) async throws -> Void) async throws {
        _ = NSApplication.shared
        let identifier = "XPastepalPanelTest_\(UUID().uuidString)"
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(identifier)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let defaults = try #require(UserDefaults(suiteName: identifier))
        let shortcuts = ShortcutService(nameRawValue: identifier, legacyDefaults: defaults)
        let board = NSPasteboard(name: .init(identifier))
        defer {
            KeyboardShortcuts.removeHandler(for: shortcuts.name)
            KeyboardShortcuts.reset(shortcuts.name)
            defaults.removePersistentDomain(forName: identifier)
            board.releaseGlobally()
            try? FileManager.default.removeItem(at: directory)
        }
        let bitmap = try #require(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 3840, pixelsHigh: 2160,
                                                  bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                                  isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        memset(try #require(bitmap.bitmapData), 0xA0, bitmap.bytesPerRow * bitmap.pixelsHigh)
        let png = try #require(bitmap.representation(using: .png, properties: [:]))
        let newest = Date()
        let items = (0..<200).map { index in
            let date = newest.addingTimeInterval(-Double(index))
            return index < 4 ? ClipItem(createdAt: date, text: "", kind: .image, sourceApp: "Test", imageData: png)
                : ClipItem(createdAt: date, text: "Card \(index)\n" + String(repeating: "A test clipboard paragraph.\n", count: 100),
                           sourceApp: "Test")
        }
        let snapshot = HistorySnapshot(version: 1, items: items, collections: [], maxItems: 500,
                                       excludedBundleIDs: "", retentionDays: 0, monitoringEnabled: false)
        try JSONEncoder().encode(snapshot).write(to: directory.appendingPathComponent("history.json"))
        let store = ClipboardStore(directory: directory, pasteboard: board, monitoring: false)
        let coordinator = AppCoordinator(store: store, shortcuts: shortcuts, panelPreferences: PanelPreferences(defaults: defaults))
        defer {
            coordinator.dismissPanel(animated: false)
            // Release the hosting view's reference to its coordinator between UI fixtures.
            NSApp.windows.compactMap { $0 as? QuickPanel }
                .filter { $0.title == "XPastepal 快捷面板" }
                .forEach { $0.contentView = nil; $0.delegate = nil }
        }
        try await body(coordinator)
        await store.flushPendingSaves()
    }

    private func canReserveEscape() -> Bool {
        var hotKey: EventHotKeyRef?
        let status = RegisterEventHotKey(UInt32(kVK_Escape), 0,
                                        EventHotKeyID(signature: 0x58505453, id: 2),
                                        GetEventDispatcherTarget(), OptionBits(kEventHotKeyExclusive), &hotKey)
        if let hotKey { UnregisterEventHotKey(hotKey) }
        return status == noErr
    }

    private func sendHotKey(id: EventHotKeyID) throws {
        var event: EventRef?
        #expect(CreateEvent(nil, OSType(kEventClassKeyboard), UInt32(kEventHotKeyPressed),
                            0, 0, &event) == noErr)
        let unwrapped = try #require(event)
        defer { ReleaseEvent(unwrapped) }
        var identifier = id
        #expect(SetEventParameter(unwrapped, UInt32(kEventParamDirectObject),
                                 UInt32(typeEventHotKeyID), MemoryLayout<EventHotKeyID>.size, &identifier) == noErr)
        // Dispatch inside this process; do not synthesize keystrokes into other applications.
        SendEventToEventTarget(unwrapped, GetEventDispatcherTarget())
    }

    private func waitUntil(_ predicate: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(2)
        while !predicate(), Date() < deadline { try await Task.sleep(for: .milliseconds(10)) }
        #expect(predicate())
    }

    private func frame(at position: PanelPosition, on screen: NSScreen) -> NSRect {
        let visible = screen.visibleFrame
        switch position {
        case .bottom: return NSRect(x: visible.minX, y: visible.minY, width: 240, height: 160)
        case .top: return NSRect(x: visible.minX, y: visible.maxY - 160, width: 240, height: 160)
        case .left: return NSRect(x: visible.minX, y: visible.minY, width: 160, height: 240)
        case .right: return NSRect(x: visible.maxX - 160, y: visible.minY, width: 160, height: 240)
        }
    }
}

@MainActor
private final class FrameRecordingPanel: QuickPanel {
    var frameTimes: [CFTimeInterval] = []
    override func setFrameOrigin(_ point: NSPoint) {
        frameTimes.append(CACurrentMediaTime())
        super.setFrameOrigin(point)
    }
}
