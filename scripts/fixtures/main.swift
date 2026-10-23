import AppKit
import SwiftUI
import XPastepalCore

private struct SelectionFixture: View {
    let item: ClipItem
    let list: Bool
    let onSelect: () -> Void
    let onActivate: () -> Void
    @State private var selected = false

    var body: some View {
        Group {
            if list {
                LibraryListRow(item: item, isSelected: selected, onSelect: select, onCopy: onActivate)
            } else {
                ClipCard(item: item, isSelected: selected, onSelect: select, onCopy: onActivate)
            }
        }
        .frame(width: 320, height: list ? 180 : 240)
        .contextMenu { Button("Fixture action") {} }
    }

    private func select() {
        selected.toggle()
        onSelect()
    }
}

// Run outside the XCTest/Swift Testing executor so AppKit owns its event loop.
let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let list = CommandLine.arguments.contains("--list")
var selections = 0
var activations = 0
var failures = 0
var releaseTime = 0.0
var latency = 0.0
let window = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 320, height: list ? 180 : 240),
                      styleMask: .borderless, backing: .buffered, defer: false)
window.isReleasedWhenClosed = false
let item = ClipItem(text: "Click interaction fixture", sourceApp: "Test")
let select = {
    selections += 1
    latency = ProcessInfo.processInfo.systemUptime - releaseTime
}
let activate = { activations += 1 }
window.contentView = NSHostingView(rootView: SelectionFixture(
    item: item, list: list, onSelect: select, onActivate: activate))
window.orderFront(nil)

func check(_ condition: Bool, _ message: String) {
    if !condition { failures += 1; print("FAIL: \(message)") }
}
func post(_ type: NSEvent.EventType, count: Int = 1, point: NSPoint = NSPoint(x: 80, y: 90)) {
    let event = NSEvent.mouseEvent(with: type, location: point, modifierFlags: [],
                                  timestamp: ProcessInfo.processInfo.systemUptime,
                                  windowNumber: window.windowNumber, context: nil,
                                  eventNumber: 1, clickCount: count, pressure: 0)!
    app.postEvent(event, atStart: false)
}
let steps: [() -> Void] = [
    { post(.leftMouseDown) },
    {
        check(selections == 0, "Pressing without releasing must not select.")
        releaseTime = ProcessInfo.processInfo.systemUptime
        post(.leftMouseUp)
    },
    {
        check(selections == 1 && activations == 0, "The first release must select without a double-click timeout.")
        post(.leftMouseDown, count: 2)
    },
    {
        check(activations == 0, "The second press must wait for release.")
        post(.leftMouseUp, count: 2)
    },
    {
        check(selections == 1 && activations == 1, "Double-click must activate exactly once without toggling selection again.")
        post(.leftMouseDown)
        post(.leftMouseDragged, point: NSPoint(x: 400, y: 90))
        post(.leftMouseUp, point: NSPoint(x: 400, y: 90))
    },
    {
        check(selections == 1 && activations == 1, "Dragging outside must cancel the click.")
        let button = NSPoint(x: list ? 301 : 293, y: list ? 90 : 213)
        post(.leftMouseDown, point: button)
        post(.leftMouseUp, point: button)
    },
    {
        check(selections == 1 && activations == 2, "The child copy button must activate once without selecting the card.")
        app.stop(nil)
        app.postEvent(NSEvent.otherEvent(with: .applicationDefined, location: .zero, modifierFlags: [],
                                        timestamp: 0, windowNumber: 0, context: nil,
                                        subtype: 0, data1: 0, data2: 0)!, atStart: false)
    }
]
func advance(_ index: Int) {
    guard index < steps.count else { return }
    steps[index]()
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) { advance(index + 1) }
}
DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { advance(0) }
app.run()
print(String(format: "%@: %@, release-to-selection callback %.1f ms", list ? "List" : "Card",
             failures == 0 ? "PASS" : "FAIL", latency * 1_000))
exit(failures == 0 ? 0 : 1)
