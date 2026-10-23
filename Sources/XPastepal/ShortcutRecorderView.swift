import KeyboardShortcuts
import SwiftUI

struct ShortcutRecorderView: View {
    @Bindable var service: ShortcutService

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            KeyboardShortcuts.Recorder("呼出 / 收起快捷面板", name: service.name) { _ in
                service.refreshStatus()
            }
            .keyboardShortcutsConflictPolicy(.init(systemShortcut: .block))
            .accessibilityIdentifier("quickPanelShortcutRecorder")

            Text("点击右侧录制框，然后按下需要的组合键。按 Esc 取消，按 Delete 清除。设置会自动保存。")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Button("恢复默认 ⌥⌘V") { service.resetToDefault() }
                    .disabled(service.isDefaultShortcut)
                Button("清除快捷键") { service.clear() }
                    .disabled(!service.hasShortcut)
                Spacer()
            }

            if let message = service.statusMessage {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
                Button("重新注册快捷键") { service.retryRegistration() }
            } else if service.isEnabled {
                Label("全局快捷键已启用，可在其他应用中按 \(service.shortcutLabel) 呼出。", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if !service.hasShortcut {
                Label("尚未设置快捷键。仍可点击菜单栏图标打开面板。", systemImage: "keyboard")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
