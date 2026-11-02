import AppKit
import Observation
import XPastepalCore

/// 从 GitHub Release 检查新版本；启动后和每 24 小时自动检查，发现新版本时提示安装并重启。
@MainActor @Observable
final class AppUpdater {
    private(set) var isChecking = false
    private(set) var isInstalling = false
    var automaticallyChecks: Bool {
        didSet {
            defaults.set(automaticallyChecks, forKey: Self.automaticKey)
            scheduleAutomaticCheck()
        }
    }

    var menuTitle: String { isInstalling ? "正在安装更新…" : isChecking ? "正在检查更新…" : "检查更新…" }
    var currentVersion: String { AppReleaseIdentity.currentVersion }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var timer: Timer?
    private static let automaticKey = "update.automaticCheck"
    private static let lastCheckKey = "update.lastCheckAt"
    private static let interval: TimeInterval = 24 * 60 * 60

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        automaticallyChecks = defaults.object(forKey: Self.automaticKey) as? Bool ?? true
    }

    func start() {
        scheduleAutomaticCheck()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 60 * 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.scheduleAutomaticCheck() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        task?.cancel()
        task = nil
    }

    func checkForUpdates() { check(userInitiated: true) }

    private func scheduleAutomaticCheck() {
        // 未打包运行（swift run / 测试）没有版本号，不自动检查。
        guard automaticallyChecks, currentVersion != "0.0.0", !isChecking, !isInstalling else { return }
        if let last = defaults.object(forKey: Self.lastCheckKey) as? Date, Date().timeIntervalSince(last) < Self.interval { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in self?.check(userInitiated: false) }
    }

    private func check(userInitiated: Bool) {
        guard !isChecking, !isInstalling else { return }
        isChecking = true
        let checker = GitHubReleaseUpdateChecker(currentVersion: currentVersion)
        task = Task { [weak self] in
            do {
                let result = try await checker.checkForUpdate()
                self?.finishCheck(.success(result), userInitiated: userInitiated)
            } catch is CancellationError {
                self?.isChecking = false
            } catch {
                self?.finishCheck(.failure(error), userInitiated: userInitiated)
            }
        }
    }

    private func finishCheck(_ result: Result<AppUpdateCheckResult, Error>, userInitiated: Bool) {
        isChecking = false
        task = nil
        defaults.set(Date(), forKey: Self.lastCheckKey)
        switch result {
        case .success(.updateAvailable(let info)):
            presentUpdateAvailable(info)
        case .success(.upToDate(let current, _)):
            if userInitiated { alert("已是最新版本", "当前版本 \(current) 已是最新。") }
        case .failure(let error):
            if userInitiated { alert("检查更新失败", error.localizedDescription, style: .warning) }
        }
    }

    private func presentUpdateAvailable(_ info: AppUpdateInfo) {
        let alert = NSAlert()
        alert.messageText = "XPastepal \(info.latestVersion) 可用"
        let notes = info.releaseNotes.isEmpty ? "" : "\n\n\(info.releaseNotes.prefix(800))"
        alert.informativeText = "当前版本 \(info.currentVersion)。\(notes)"
        alert.addButton(withTitle: info.canInstallAutomatically ? "安装并重启" : "下载")
        alert.addButton(withTitle: "查看发布页")
        alert.addButton(withTitle: "稍后")
        NSApp.activate(ignoringOtherApps: true)
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            if info.canInstallAutomatically { install(info) } else { NSWorkspace.shared.open(info.downloadURL) }
        case .alertSecondButtonReturn:
            NSWorkspace.shared.open(info.releasePageURL)
        default:
            break
        }
    }

    private func install(_ info: AppUpdateInfo) {
        guard !isInstalling else { return }
        isInstalling = true
        task = Task { [weak self] in
            do {
                let installation = try await AppUpdateInstaller().prepareInstallation(for: info)
                try installation.launchInstaller()
                NSApp.terminate(nil)
            } catch {
                guard let self else { return }
                self.isInstalling = false
                self.task = nil
                let alert = NSAlert()
                alert.alertStyle = .warning
                alert.messageText = "安装更新失败"
                alert.informativeText = error.localizedDescription
                alert.addButton(withTitle: "查看发布页")
                alert.addButton(withTitle: "好")
                NSApp.activate(ignoringOtherApps: true)
                if alert.runModal() == .alertFirstButtonReturn { NSWorkspace.shared.open(info.releasePageURL) }
            }
        }
    }

    private func alert(_ title: String, _ message: String, style: NSAlert.Style = .informational) {
        let alert = NSAlert()
        alert.alertStyle = style
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "好")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}
