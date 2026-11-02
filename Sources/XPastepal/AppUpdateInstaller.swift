import Foundation
import XPastepalCore

enum AppUpdateInstallError: LocalizedError, Sendable {
    case unsupportedAsset
    case downloadFailed(String)
    case appIsNotBundled
    case installLocationNotWritable(String)
    case extractionFailed(String)
    case noApplicationBundleFound
    case invalidBundleIdentifier(String?)
    case versionIsNotNewer(String?)
    case signatureVerificationFailed(String)
    case invalidTeamIdentifier(String?)
    case notarizationAssessmentFailed(String)
    case installerLaunchFailed(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedAsset: return "这个版本没有可自动安装的文件。"
        case .downloadFailed(let message): return "下载更新失败：\(message)"
        case .appIsNotBundled: return "XPastepal 不是从 .app 运行的，无法自动替换。"
        case .installLocationNotWritable(let path): return "没有权限替换 \(path) 中的应用，请手动安装。"
        case .extractionFailed(let message): return "无法读取更新文件：\(message)"
        case .noApplicationBundleFound: return "更新文件中没有找到应用。"
        case .invalidBundleIdentifier(let id): return "下载的应用 Bundle ID 不匹配：\(id ?? "未知")。"
        case .versionIsNotNewer(let version): return "下载的应用版本不比当前版本新：\(version ?? "未知")。"
        case .signatureVerificationFailed(let message): return "下载的应用未通过签名校验：\(message)"
        case .invalidTeamIdentifier(let team): return "下载的应用签名团队不匹配：\(team ?? "未知")。"
        case .notarizationAssessmentFailed(let message): return "下载的应用未通过 Gatekeeper 公证检查：\(message)"
        case .installerLaunchFailed(let message): return "无法启动更新安装：\(message)"
        }
    }
}

/// 下载并校验新版本，退出后由独立脚本替换当前 .app 并重新打开。
struct AppUpdateInstaller {
    func prepareInstallation(for info: AppUpdateInfo) async throws -> AppUpdateInstallation {
        guard info.canInstallAutomatically else { throw AppUpdateInstallError.unsupportedAsset }
        let currentAppURL = Bundle.main.bundleURL
        guard currentAppURL.pathExtension.lowercased() == "app" else { throw AppUpdateInstallError.appIsNotBundled }
        let parent = currentAppURL.deletingLastPathComponent()
        guard FileManager.default.isWritableFile(atPath: parent.path) else {
            throw AppUpdateInstallError.installLocationNotWritable(parent.path)
        }

        let workRoot = FileManager.default.temporaryDirectory.appendingPathComponent("XPastepalUpdate-\(UUID().uuidString)", isDirectory: true)
        let extractionURL = workRoot.appendingPathComponent("Extracted", isDirectory: true)
        try FileManager.default.createDirectory(at: extractionURL, withIntermediateDirectories: true)

        let archiveName = info.downloadAssetName.map { ($0 as NSString).lastPathComponent } ?? info.downloadURL.lastPathComponent
        let archiveURL = workRoot.appendingPathComponent(archiveName)
        try FileManager.default.moveItem(at: try await download(info.downloadURL), to: archiveURL)

        let appURL: URL
        switch info.downloadKind {
        case .applicationZipArchive:
            try await run("/usr/bin/ditto", ["-x", "-k", archiveURL.path, extractionURL.path], as: AppUpdateInstallError.extractionFailed)
            appURL = try findApplication(in: extractionURL)
        case .diskImage:
            appURL = try await copyApplication(fromDiskImage: archiveURL, to: extractionURL, workRoot: workRoot)
        case .other:
            throw AppUpdateInstallError.unsupportedAsset
        }
        try await validate(appURL, latestVersion: info.latestVersion)

        let scriptURL = workRoot.appendingPathComponent("install-xpastepal-update.sh")
        try Self.installerScript.write(to: scriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)
        return AppUpdateInstallation(scriptURL: scriptURL, downloadedAppURL: appURL, currentAppURL: currentAppURL, workRootURL: workRoot)
    }

    private func download(_ url: URL) async throws -> URL {
        var request = URLRequest(url: url)
        request.setValue("\(AppReleaseIdentity.name)/\(AppReleaseIdentity.currentVersion)", forHTTPHeaderField: "User-Agent")
        do {
            let (fileURL, response) = try await URLSession.shared.download(for: request)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                throw AppUpdateInstallError.downloadFailed("HTTP \(http.statusCode)")
            }
            return fileURL
        } catch let error as AppUpdateInstallError {
            throw error
        } catch {
            throw AppUpdateInstallError.downloadFailed(error.localizedDescription)
        }
    }

    private func copyApplication(fromDiskImage imageURL: URL, to destination: URL, workRoot: URL) async throws -> URL {
        let mountURL = workRoot.appendingPathComponent("Mounted", isDirectory: true)
        try FileManager.default.createDirectory(at: mountURL, withIntermediateDirectories: true)
        try await run("/usr/bin/hdiutil", ["attach", "-nobrowse", "-readonly", "-mountpoint", mountURL.path, imageURL.path],
                      as: AppUpdateInstallError.extractionFailed)
        do {
            let mountedApp = try findApplication(in: mountURL)
            let copiedApp = destination.appendingPathComponent(mountedApp.lastPathComponent, isDirectory: true)
            try await run("/usr/bin/ditto", ["--noqtn", mountedApp.path, copiedApp.path], as: AppUpdateInstallError.extractionFailed)
            _ = try? await run("/usr/bin/hdiutil", ["detach", mountURL.path], as: AppUpdateInstallError.extractionFailed)
            return copiedApp
        } catch {
            _ = try? await run("/usr/bin/hdiutil", ["detach", "-force", mountURL.path], as: AppUpdateInstallError.extractionFailed)
            throw error
        }
    }

    private func findApplication(in directory: URL) throws -> URL {
        guard let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil,
                                                              options: [.skipsHiddenFiles]) else {
            throw AppUpdateInstallError.noApplicationBundleFound
        }
        var fallback: URL?
        for case let url as URL in enumerator where url.pathExtension.lowercased() == "app" {
            enumerator.skipDescendants()
            if Bundle(url: url)?.bundleIdentifier == AppReleaseIdentity.bundleIdentifier { return url }
            fallback = fallback ?? url
        }
        guard let fallback else { throw AppUpdateInstallError.noApplicationBundleFound }
        return fallback
    }

    private func validate(_ appURL: URL, latestVersion: String) async throws {
        let bundle = Bundle(url: appURL)
        guard bundle?.bundleIdentifier == AppReleaseIdentity.bundleIdentifier else {
            throw AppUpdateInstallError.invalidBundleIdentifier(bundle?.bundleIdentifier)
        }
        let version = bundle?.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        guard let version, AppReleaseVersion(version) >= AppReleaseVersion(latestVersion),
              AppReleaseVersion(version) > AppReleaseVersion(AppReleaseIdentity.currentVersion) else {
            throw AppUpdateInstallError.versionIsNotNewer(version)
        }

        try await run("/usr/bin/codesign", ["--verify", "--deep", "--strict", appURL.path], as: AppUpdateInstallError.signatureVerificationFailed)
        let details = try await run("/usr/bin/codesign", ["-dv", "--verbose=4", appURL.path], as: AppUpdateInstallError.signatureVerificationFailed)
        let team = details.components(separatedBy: .newlines)
            .first { $0.hasPrefix("TeamIdentifier=") }
            .map { String($0.dropFirst("TeamIdentifier=".count)).trimmingCharacters(in: .whitespaces) }
        guard team == AppReleaseIdentity.teamIdentifier else { throw AppUpdateInstallError.invalidTeamIdentifier(team) }

        try await run("/usr/sbin/spctl", ["--assess", "--type", "execute", "--verbose=4", appURL.path],
                      as: AppUpdateInstallError.notarizationAssessmentFailed)
    }

    @discardableResult
    private func run(_ executable: String, _ arguments: [String], as failure: (String) -> AppUpdateInstallError) async throws -> String {
        let (status, message) = await Task.detached(priority: .utility) { () -> (Int32, String) in
            let process = Process()
            let output = Pipe()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            process.standardOutput = output
            process.standardError = output
            do { try process.run() } catch { return (-1, error.localizedDescription) }
            let data = output.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            return (process.terminationStatus, String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines))
        }.value
        guard status == 0 else { throw failure(message.isEmpty ? "命令执行失败" : message) }
        return message
    }

    /// 等待旧进程退出后替换应用；复制失败时还原旧版本。
    private static let installerScript = """
    #!/bin/zsh
    set -euo pipefail
    source_app="$1"
    target_app="$2"
    app_pid="$3"
    work_root="$4"
    backup_app="${target_app}.previous-update"
    while /bin/kill -0 "$app_pid" 2>/dev/null; do /bin/sleep 0.2; done
    /bin/rm -rf "$backup_app"
    if [ -d "$target_app" ]; then /bin/mv "$target_app" "$backup_app"; fi
    if /usr/bin/ditto "$source_app" "$target_app"; then
        /usr/bin/xattr -dr com.apple.quarantine "$target_app" 2>/dev/null || true
        /usr/bin/open "$target_app"
        /bin/rm -rf "$backup_app" "$work_root"
    else
        /bin/rm -rf "$target_app"
        if [ -d "$backup_app" ]; then
            /bin/mv "$backup_app" "$target_app"
            /usr/bin/open "$target_app" 2>/dev/null || true
        fi
        exit 1
    fi
    """
}

struct AppUpdateInstallation {
    let scriptURL: URL
    let downloadedAppURL: URL
    let currentAppURL: URL
    let workRootURL: URL

    func launchInstaller() throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = [scriptURL.path, downloadedAppURL.path, currentAppURL.path,
                             "\(ProcessInfo.processInfo.processIdentifier)", workRootURL.path]
        do { try process.run() } catch { throw AppUpdateInstallError.installerLaunchFailed(error.localizedDescription) }
    }
}
