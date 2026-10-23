import AppKit
import Carbon

/// Reserves Escape only while the visible panel has lost focus to another app.
@MainActor
final class PanelEscapeShortcut {
    var onEscape: (() -> Void)?
    private(set) var isEnabled = false
    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private var fallbackMonitor: Any?
    private let identifier = EventHotKeyID(signature: 0x58504553, id: 1)

    func setEnabled(_ enabled: Bool) {
        guard enabled != isEnabled else { return }
        isEnabled = enabled
        guard enabled else { unregister(); return }

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(
            GetEventDispatcherTarget(),
            { _, event, context in
                guard let event, let context else { return OSStatus(eventNotHandledErr) }
                return MainActor.assumeIsolated {
                    let owner = Unmanaged<PanelEscapeShortcut>.fromOpaque(context).takeUnretainedValue()
                    return owner.handle(event)
                }
            },
            1, &eventType, Unmanaged.passUnretained(self).toOpaque(), &handler
        )
        if status == noErr,
           RegisterEventHotKey(UInt32(kVK_Escape), 0, identifier, GetEventDispatcherTarget(),
                               OptionBits(kEventHotKeyExclusive), &hotKey) == noErr {
            return
        }

        // If another utility owns Escape, observe it when accessibility access is available.
        unregister()
        fallbackMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == kVK_Escape,
                  event.modifierFlags.intersection([.command, .control, .option, .shift]).isEmpty else { return }
            MainActor.assumeIsolated {
                guard let self, self.isEnabled else { return }
                self.onEscape?()
            }
        }
    }

    private func handle(_ event: EventRef) -> OSStatus {
        var received = EventHotKeyID()
        guard isEnabled,
              GetEventParameter(event, UInt32(kEventParamDirectObject), UInt32(typeEventHotKeyID),
                                nil, MemoryLayout<EventHotKeyID>.size, nil, &received) == noErr,
              received.signature == identifier.signature, received.id == identifier.id else {
            return OSStatus(eventNotHandledErr)
        }
        onEscape?()
        return noErr
    }

    private func unregister() {
        if let hotKey { UnregisterEventHotKey(hotKey); self.hotKey = nil }
        if let handler { RemoveEventHandler(handler); self.handler = nil }
        if let fallbackMonitor { NSEvent.removeMonitor(fallbackMonitor); self.fallbackMonitor = nil }
    }

    deinit {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let handler { RemoveEventHandler(handler) }
        if let fallbackMonitor { NSEvent.removeMonitor(fallbackMonitor) }
    }
}
