import Foundation
import Testing
@testable import XPastepalCore

struct AppUpdateCheckerTests {
    @Test("版本号忽略前缀 v 并按数字比较")
    func comparesVersions() {
        #expect(AppReleaseVersion("v0.3.0") == AppReleaseVersion("0.3.0"))
        #expect(AppReleaseVersion("V1.0") == AppReleaseVersion("1.0.0"))
        #expect(AppReleaseVersion("0.2.10") > AppReleaseVersion("0.2.9"))
        #expect(AppReleaseVersion("1.0.0") > AppReleaseVersion("0.9.9"))
    }

    @Test("有新版本时优先选择应用 DMG")
    func picksDiskImage() async throws {
        let checker = GitHubReleaseUpdateChecker(currentVersion: "0.2.2", fetch: Self.respond(
            tag: "v0.3.0",
            assets: ["notes.txt", "XPastepal-0.3.0.zip", "XPastepal-0.3.0.dmg"]))
        guard case .updateAvailable(let info) = try await checker.checkForUpdate() else {
            Issue.record("应检测到新版本")
            return
        }
        #expect(info.latestVersion == "v0.3.0")
        #expect(info.downloadAssetName == "XPastepal-0.3.0.dmg")
        #expect(info.downloadKind == .diskImage)
        #expect(info.releaseNotes == "更新说明")
        #expect(info.canInstallAutomatically)
    }

    @Test("没有可安装文件时退回发布页")
    func fallsBackToReleasePage() async throws {
        let checker = GitHubReleaseUpdateChecker(currentVersion: "0.2.2", fetch: Self.respond(tag: "0.3.0", assets: ["notes.txt"]))
        guard case .updateAvailable(let info) = try await checker.checkForUpdate() else {
            Issue.record("应检测到新版本")
            return
        }
        #expect(info.downloadURL == info.releasePageURL)
        #expect(!info.canInstallAutomatically)
    }

    @Test("版本相同或更旧时视为最新")
    func upToDate() async throws {
        let checker = GitHubReleaseUpdateChecker(currentVersion: "0.3.0", fetch: Self.respond(tag: "v0.3.0", assets: []))
        #expect(try await checker.checkForUpdate() == .upToDate(currentVersion: "0.3.0", latestVersion: "v0.3.0"))
    }

    @Test("HTTP 错误抛出状态码")
    func reportsHTTPStatus() async {
        let checker = GitHubReleaseUpdateChecker(currentVersion: "0.3.0", fetch: Self.respond(tag: "v0.3.0", assets: [], status: 404))
        await #expect(throws: AppUpdateCheckError.httpStatus(404)) { try await checker.checkForUpdate() }
    }

    private static func respond(tag: String, assets: [String], status: Int = 200) -> GitHubReleaseUpdateChecker.Fetch {
        { request in
            let base = "https://github.com/lwj1994/x_pastepal/releases"
            let json: [String: Any] = [
                "tag_name": tag,
                "html_url": "\(base)/tag/\(tag)",
                "body": "更新说明\n",
                "assets": assets.map { ["name": $0, "browser_download_url": "\(base)/download/\(tag)/\($0)"] }
            ]
            let data = try JSONSerialization.data(withJSONObject: json)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
            return (data, response)
        }
    }
}
