import AppKit
import SwiftUI
import ServiceManagement
import PermissionFlow
import XPastepalCore

struct PreferencesView: View {
    @Bindable var coordinator: AppCoordinator
    @Bindable var store: ClipboardStore
    @State private var loginStatus = SMAppService.mainApp.status
    @State private var loginError: String?
    @State private var authorizationState = PermissionAccess.accessibilityState
    private let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        TabView {
            generalSettings
                .tabItem { Label("通用", systemImage: "gearshape") }
            shortcutSettings
                .tabItem { Label("快捷键", systemImage: "keyboard") }
            panelSettings
                .tabItem { Label("快捷面板", systemImage: "rectangle.bottomthird.inset.filled") }
            BackupSyncSettingsView(store: store)
                .tabItem { Label("备份与同步", systemImage: "icloud") }
            privacySettings
                .tabItem { Label("隐私与权限", systemImage: "hand.raised") }
        }
        .padding(12)
        .frame(width: 600, height: 580)
        .onReceive(timer) { _ in refreshState() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshState()
        }
    }

    private var generalSettings: some View {
        Form {
            Section("记录与存储") {
                Toggle("自动记录剪贴板", isOn: Binding(
                    get: { store.isMonitoring },
                    set: { $0 ? store.startMonitoring() : store.stopMonitoring() }))
                Picker("历史数量上限", selection: $store.maxItems) {
                    Text("100 条").tag(100)
                    Text("500 条").tag(500)
                    Text("1,000 条").tag(1000)
                    Text("5,000 条").tag(5000)
                }
                Picker("历史保留时间", selection: $store.retentionDays) {
                    Text("永久").tag(0)
                    Text("7 天").tag(7)
                    Text("30 天").tag(30)
                    Text("90 天").tag(90)
                }
                Text("收藏的内容不受自动清理限制。可在“备份与同步”管理本地快照和 iCloud。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("粘贴队列") {
                Toggle("连续复制自动排队", isOn: Binding(
                    get: { coordinator.panelPreferences.autoPasteQueue },
                    set: { coordinator.panelPreferences.autoPasteQueue = $0; coordinator.updatePasteQueueMonitor() }))
                Text("10 秒内连续复制的多条内容会按复制顺序排队，在其他应用每按一次 ⌘V 粘贴下一条，全部粘完恢复正常。复制之间粘贴过，或在快捷面板选择内容，都不会排队。")
                    .font(.caption).foregroundStyle(.secondary)
                if coordinator.panelPreferences.autoPasteQueue && authorizationState != .granted {
                    HStack {
                        Label("需要辅助功能权限才能识别 ⌘V", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Spacer()
                        Button("启用…") { PermissionAccess.authorizeAccessibility() }
                    }.font(.caption)
                }
            }
            Section("启动") {
                Toggle("登录时启动", isOn: Binding(
                    get: { loginStatus == .enabled || loginStatus == .requiresApproval },
                    set: { value in
                        do {
                            if value { try SMAppService.mainApp.register() }
                            else { try SMAppService.mainApp.unregister() }
                            loginError = nil
                        } catch { loginError = error.localizedDescription }
                        loginStatus = SMAppService.mainApp.status
                    }))
                if loginStatus == .requiresApproval {
                    Button("在系统设置中批准登录启动…") { SMAppService.openSystemSettingsLoginItems() }
                        .font(.caption)
                }
                if let loginError { Text(loginError).font(.caption).foregroundStyle(.orange) }
            }
            Section {
                HStack {
                    Text("XPastepal \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "开发版")").foregroundStyle(.secondary)
                    Spacer()
                    Button("打开数据文件夹") {
                        do {
                            try FileManager.default.createDirectory(at: store.directory, withIntermediateDirectories: true,
                                                                    attributes: [.posixPermissions: 0o700])
                            NSWorkspace.shared.open(store.directory)
                        } catch { store.errorMessage = "无法打开数据文件夹：\(error.localizedDescription)" }
                    }
                }.font(.caption)
            }
        }
        .formStyle(.grouped)
    }

    private var shortcutSettings: some View {
        Form {
            Section("全局快捷键") {
                ShortcutRecorderView(service: coordinator.shortcuts)
                Text("全局快捷键无需辅助功能权限。辅助功能仅用于自动粘贴和粘贴队列。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("面板内操作") {
                keyHint("选择内容", keys: "← / → / ↑ / ↓")
                keyHint("粘贴选中内容", keys: "Return")
                keyHint("收起面板", keys: "Esc")
            }
            Section {
                Button("打开快捷面板") { coordinator.toggleQuickPanel() }
            }
        }
        .formStyle(.grouped)
    }

    private var privacySettings: some View {
        Form {
            Section("辅助功能") {
                HStack {
                    Label(permissionStatusTitle,
                          systemImage: authorizationState == .granted ? "checkmark.circle.fill" : "keyboard")
                    Spacer()
                    Button(authorizationState == .granted ? "管理权限" : "启用…") {
                        PermissionAccess.authorizeAccessibility()
                    }
                    .help("打开辅助功能设置，并显示 XPastepal 拖拽授权浮层")
                }
                Text(authorizationState == .granted
                     ? "辅助功能用于把选中的内容粘贴到目标应用，并让粘贴队列识别 ⌘V。"
                     : "点击启用，将浮层里的 XPastepal 拖入辅助功能列表并打开开关。未授权时仍可复制，再按 ⌘V 粘贴。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("忽略的应用") {
                TextField("每行一个 Bundle ID，例如 com.example.app", text: $store.excludedBundleIDs, axis: .vertical)
                    .lineLimit(4...6).font(.system(.caption, design: .monospaced))
                Text("自动忽略密码管理器及标为机密或临时的剪贴板内容。新增的应用 ID 用逗号或换行分隔。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section {
                Label(store.cloudSyncEnabled ? "已开启 iCloud：历史会同步到你的私有云空间。" : "iCloud 同步未开启，剪贴板历史仅保存在本机。",
                      systemImage: store.cloudSyncEnabled ? "icloud" : "internaldrive")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private var panelSettings: some View {
        @Bindable var preferences = coordinator.panelPreferences
        return Form {
            Section("布局") {
                Picker("面板位置", selection: $preferences.position) {
                    ForEach(PanelPosition.allCases) { position in
                        Text(position.title).tag(position)
                    }
                }
                Text("新的位置会在下次呼出快捷面板时生效。")
                    .font(.caption).foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("卡片宽度")
                        Spacer()
                        Text("\(Int(preferences.cardWidth)) 点")
                            .monospacedDigit().foregroundStyle(.secondary)
                    }
                    Slider(value: $preferences.cardWidth, in: 180...300, step: 10)
                        .accessibilityLabel("卡片宽度")
                }
            }
            Section("交互") {
                Toggle("保持面板打开", isOn: $preferences.staysOpen)
                Toggle("默认粘贴为纯文本", isOn: $preferences.plainTextByDefault)
                Toggle("仅复制到剪贴板", isOn: $preferences.copyOnly)
                Text("启用仅复制后，选择的内容会放入剪贴板，可自行按 ⌘V 粘贴。纯文本模式会移除富文本格式。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section {
                Button("预览快捷面板") { coordinator.toggleQuickPanel() }
            }
        }
        .formStyle(.grouped)
    }

    private func keyHint(_ title: String, keys: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(keys).font(.system(.body, design: .monospaced)).foregroundStyle(.secondary)
        }
    }

    private func refreshState() {
        authorizationState = PermissionAccess.accessibilityState
        loginStatus = SMAppService.mainApp.status
        coordinator.shortcuts.refreshStatus()
    }

    private var permissionStatusTitle: String {
        switch authorizationState {
        case .granted: return "自动粘贴已就绪"
        case .notGranted: return "自动粘贴需要辅助功能权限"
        case .checking: return "正在检查辅助功能权限"
        case .unknown: return "辅助功能权限状态未知"
        }
    }
}
