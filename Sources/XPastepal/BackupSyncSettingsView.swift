import AppKit
import SwiftUI
import XPastepalCore

struct BackupSyncSettingsView: View {
    @Bindable var store: ClipboardStore
    @State private var selectedBackup: LocalBackupInfo?
    @State private var isWorking = false
    @State private var confirmEnable = false

    var body: some View {
        Form {
            Section("本地备份") {
                Toggle("自动备份", isOn: $store.automaticBackupEnabled)
                Picker("备份间隔", selection: $store.backupIntervalHours) {
                    Text("1 小时").tag(1)
                    Text("6 小时").tag(6)
                    Text("每天").tag(24)
                }
                .disabled(!store.automaticBackupEnabled)
                Text("有更改时按间隔备份，保留最近 30 份，总计最多 512 MB。导入和接收云端更改前也会备份。")
                    .font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button("立即备份") {
                        perform { await store.createBackup() }
                    }
                    Button("打开备份文件夹") {
                        do {
                            try FileManager.default.createDirectory(at: store.backupDirectory,
                                                                    withIntermediateDirectories: true,
                                                                    attributes: [.posixPermissions: 0o700])
                            NSWorkspace.shared.open(store.backupDirectory)
                        } catch { store.errorMessage = error.localizedDescription }
                    }
                    Spacer()
                    Button("刷新") { perform { await store.refreshBackups() } }
                }
                if let backup = store.backups.first {
                    Text("最近备份：\(backup.createdAt.formatted(date: .abbreviated, time: .shortened)) · \(store.backups.count) 份")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if !store.backups.isEmpty {
                    Menu("从本地备份恢复…") {
                        ForEach(store.backups) { backup in
                            Button("\(backup.createdAt.formatted(date: .abbreviated, time: .standard)) · \(ByteCountFormatter.string(fromByteCount: Int64(backup.byteCount), countStyle: .file))") {
                                selectedBackup = backup
                            }
                        }
                    }
                }
                if let error = store.backupError {
                    Text(error).font(.caption).foregroundStyle(.orange).textSelection(.enabled)
                }
            }
            .disabled(isWorking)
            Section("iCloud 多台 Mac 同步") {
                Toggle("同步到我的 iCloud", isOn: Binding(
                    get: { store.cloudSyncEnabled },
                    set: { enabled in
                        if enabled { confirmEnable = true }
                        else { Task { await store.setCloudSyncEnabled(false) } }
                    }
                ))
                .disabled(store.cloudConfigurationError != nil && !store.cloudSyncEnabled)
                Text("使用同一 Apple 账户的 Mac 可同步文本、链接、图片、富文本、收藏和集合。删除及自动清理会同步到其他 Mac。文件路径和本机设置不参与同步。")
                    .font(.caption).foregroundStyle(.secondary)
                HStack {
                    if store.isSyncing { ProgressView().controlSize(.small) }
                    Text(store.syncStatus).font(.caption).textSelection(.enabled)
                    Spacer()
                    Button("立即同步") { Task { await store.synchronizeNow() } }
                        .disabled(!store.cloudSyncEnabled || store.isSyncing)
                }
                if let date = store.lastSyncDate {
                    Text("最近成功：\(date.formatted(date: .abbreviated, time: .standard))")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if let configurationError = store.cloudConfigurationError {
                    Text(configurationError).font(.caption).foregroundStyle(.orange).textSelection(.enabled)
                }
                Text("应用运行时约每分钟同步一次，离线更改会在恢复连接后重试。本地备份留在各自的 Mac。")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .task { await store.refreshBackups() }
        .alert("启用 iCloud 同步？", isPresented: $confirmEnable) {
            Button("取消", role: .cancel) {}
            Button("启用") { Task { await store.setCloudSyncEnabled(true) } }
        } message: {
            Text("现有历史及今后的记录将上传到当前 Apple 账户的私有 iCloud 空间，并与其他已启用同步的 Mac 合并。删除和自动清理也会同步。")
        }
        .alert("合并恢复此备份？", isPresented: Binding(
            get: { selectedBackup != nil },
            set: { if !$0 { selectedBackup = nil } }
        )) {
            Button("取消", role: .cancel) { selectedBackup = nil }
            Button("恢复") {
                guard let backup = selectedBackup else { return }
                selectedBackup = nil
                perform { await store.restoreBackup(backup) }
            }
        } message: {
            Text("补回缺失的记录和集合，保留当前编辑与设置。已删除的内容以新记录恢复；开启同步时，恢复的内容也会同步。")
        }
    }

    private func perform(_ operation: @escaping @MainActor () async -> Void) {
        isWorking = true
        Task {
            await operation()
            isWorking = false
        }
    }
}
