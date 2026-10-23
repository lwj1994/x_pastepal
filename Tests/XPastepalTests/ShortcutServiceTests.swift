import AppKit
import Carbon
import KeyboardShortcuts
import Testing
@testable import XPastepal

@Suite(.serialized)
@MainActor
struct ShortcutServiceTests {
    @Test("首次运行采用默认组合，并保留旧版 Control Shift V 偏好")
    func migratesLegacyPreference() throws {
        try withFixture { fixture in
            fixture.defaults.set(1, forKey: "shortcutMode")
            let service = fixture.makeService()
            #expect(KeyboardShortcuts.getShortcut(for: service.name) == .init(.v, modifiers: [.control, .shift]))
            #expect(service.hasShortcut)
            #expect(!service.isDefaultShortcut)
        }
        try withFixture { fixture in
            let service = fixture.makeService()
            #expect(KeyboardShortcuts.getShortcut(for: service.name) == ShortcutService.defaultShortcut)
            #expect(service.isDefaultShortcut)
        }
    }

    @Test("自定义组合跨服务实例保留，不被旧版偏好覆盖")
    func preservesCustomShortcut() throws {
        try withFixture { fixture in
            let service = fixture.makeService()
            let custom = KeyboardShortcuts.Shortcut(.p, modifiers: [.control, .option, .command])
            KeyboardShortcuts.setShortcut(custom, for: service.name)
            fixture.defaults.set(1, forKey: "shortcutMode")

            let reopened = fixture.makeService()
            #expect(KeyboardShortcuts.getShortcut(for: reopened.name) == custom)
            #expect(reopened.shortcutLabel == String(describing: custom))
            #expect(reopened.hasShortcut)
            #expect(!reopened.isDefaultShortcut)
        }
    }

    @Test("清除后重启仍禁用，恢复默认才重新启用默认组合")
    func preservesExplicitlyClearedShortcut() throws {
        try withFixture { fixture in
            fixture.defaults.set(1, forKey: "shortcutMode")
            let service = fixture.makeService()
            service.clear()

            let reopened = fixture.makeService()
            #expect(KeyboardShortcuts.getShortcut(for: reopened.name) == nil)
            #expect(!reopened.hasShortcut)
            #expect(!reopened.isEnabled)
            #expect(reopened.shortcutLabel == "未设置")
            reopened.resetToDefault()
            #expect(KeyboardShortcuts.getShortcut(for: reopened.name) == ShortcutService.defaultShortcut)
            #expect(reopened.isDefaultShortcut)
        }
    }

    @Test("注册冲突显示错误，释放占用后可重试，停止后不继续响应")
    func conflictAndRegistrationLifecycle() throws {
        try withFixture { fixture in
            let service = fixture.makeService()
            // 独立冷门组合用于真实注册冲突测试，不发送按键事件。
            let shortcut = KeyboardShortcuts.Shortcut(.f19, modifiers: [.control, .option, .shift, .command])
            KeyboardShortcuts.setShortcut(shortcut, for: service.name)
            var reservedHotKey: EventHotKeyRef?
            let status = RegisterEventHotKey(
                UInt32(shortcut.carbonKeyCode), UInt32(shortcut.carbonModifiers),
                EventHotKeyID(signature: OSType(0x58505453), id: 1),
                GetEventDispatcherTarget(), OptionBits(kEventHotKeyExclusive), &reservedHotKey)
            #expect(status == noErr)
            let reserved = try #require(reservedHotKey)
            defer { if reservedHotKey != nil { UnregisterEventHotKey(reserved) } }

            service.start()
            defer { service.stop() }
            #expect(!service.isEnabled)
            #expect(service.statusMessage?.contains("注册失败") == true)

            UnregisterEventHotKey(reserved)
            reservedHotKey = nil
            service.retryRegistration()
            #expect(service.isEnabled)
            #expect(service.statusMessage == nil)
            service.start()
            #expect(service.isEnabled)
            service.stop()
            #expect(!service.isEnabled)
            #expect(!KeyboardShortcuts.isEnabled(for: service.name))
            #expect(KeyboardShortcuts.getShortcut(for: service.name) == shortcut)
        }
    }

    private func withFixture(_ body: (Fixture) throws -> Void) throws {
        let identifier = "XPastepalShortcutTest_\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: identifier))
        let fixture = Fixture(identifier: identifier, defaults: defaults)
        defer {
            let name = KeyboardShortcuts.Name(rawValue: identifier)!
            KeyboardShortcuts.removeHandler(for: name)
            KeyboardShortcuts.reset(name)
            defaults.removePersistentDomain(forName: identifier)
        }
        try body(fixture)
    }

    private struct Fixture {
        let identifier: String
        let defaults: UserDefaults

        @MainActor
        func makeService() -> ShortcutService {
            ShortcutService(nameRawValue: identifier, legacyDefaults: defaults)
        }
    }
}
