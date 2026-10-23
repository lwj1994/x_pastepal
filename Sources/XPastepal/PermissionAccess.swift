import AppKit
import PermissionFlow

/// 统一使用 PermissionFlow 查询和引导辅助功能权限；读取状态不会弹出授权请求。
@MainActor
enum PermissionAccess {
    static var accessibilityState: PermissionAuthorizationState {
        PermissionStatusRegistry.provider(for: .accessibility).authorizationState()
    }

    static var isAccessibilityGranted: Bool { accessibilityState == .granted }

    // 保持 controller 存活，让浮层可以跟随系统设置并提供原生 .app 拖拽。
    private static let controller = PermissionFlow.makeController(
        configuration: PermissionFlowConfiguration(
            promptForAccessibilityTrust: false,
            localeIdentifier: "zh-Hans"
        )
    )

    static func authorizeAccessibility() {
        let mouse = NSEvent.mouseLocation
        controller.authorize(
            pane: .accessibility,
            suggestedAppURLs: [Bundle.main.bundleURL],
            sourceFrameInScreen: CGRect(x: mouse.x - 16, y: mouse.y - 16, width: 32, height: 32)
        )
    }
}
