import AppKit
import SwiftUI

extension View {
    /// Use AppKit's click count so selection never waits for a double-tap recognizer.
    func clipClickActions(onSelect: @escaping () -> Void, onActivate: @escaping () -> Void) -> some View {
        onTapGesture {
            guard let event = NSApp.currentEvent, event.type == .leftMouseUp else {
                onSelect()
                return
            }
            switch event.clickCount {
            case 1: onSelect()
            case 2: onActivate()
            default: break
            }
        }
    }
}
