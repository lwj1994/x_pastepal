import AppKit
import Observation

enum PanelPosition: String, CaseIterable, Identifiable {
    case bottom, top, left, right
    var id: String { rawValue }
    var title: String {
        switch self {
        case .bottom: return "屏幕底部"
        case .top: return "屏幕顶部"
        case .left: return "屏幕左侧"
        case .right: return "屏幕右侧"
        }
    }
    var isVertical: Bool { self == .left || self == .right }
}

@MainActor @Observable
final class PanelPreferences {
    var position: PanelPosition { didSet { defaults.set(position.rawValue, forKey: "panel.position") } }
    var staysOpen: Bool { didSet { defaults.set(staysOpen, forKey: "panel.staysOpen") } }
    var plainTextByDefault: Bool { didSet { defaults.set(plainTextByDefault, forKey: "panel.plainText") } }
    var copyOnly: Bool { didSet { defaults.set(copyOnly, forKey: "panel.copyOnly") } }
    var cardWidth: Double { didSet { defaults.set(cardWidth, forKey: "panel.cardWidth") } }
    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        position = PanelPosition(rawValue: defaults.string(forKey: "panel.position") ?? "") ?? .bottom
        staysOpen = defaults.bool(forKey: "panel.staysOpen")
        plainTextByDefault = defaults.bool(forKey: "panel.plainText")
        copyOnly = defaults.bool(forKey: "panel.copyOnly")
        let saved = defaults.double(forKey: "panel.cardWidth")
        cardWidth = saved == 0 ? 228 : min(300, max(180, saved))
    }
}
