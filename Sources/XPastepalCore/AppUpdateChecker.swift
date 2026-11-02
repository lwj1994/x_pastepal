import Foundation

/// 发布渠道与签名身份；自动更新只接受同一 Bundle ID 和团队签名的版本。
public enum AppReleaseIdentity {
    public static let name = "XPastepal"
    public static let bundleIdentifier = "milu.pastepal"
    public static let repositoryOwner = "lwj1994"
    public static let repositoryName = "x_pastepal"
    public static let teamIdentifier = "66NB8SX5ZT"

    public static var currentVersion: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "0.0.0"
    }
}

public enum AppUpdateDownloadKind: Equatable, Sendable {
    case applicationZipArchive
    case diskImage
    case other
}

public struct AppUpdateInfo: Equatable, Sendable {
    public let currentVersion: String
    public let latestVersion: String
    public let releaseNotes: String
    public let releasePageURL: URL
    public let downloadURL: URL
    public let downloadAssetName: String?
    public let downloadKind: AppUpdateDownloadKind

    public var canInstallAutomatically: Bool { downloadKind != .other }
}

public enum AppUpdateCheckResult: Equatable, Sendable {
    case upToDate(currentVersion: String, latestVersion: String)
    case updateAvailable(AppUpdateInfo)
}

public enum AppUpdateCheckError: LocalizedError, Equatable {
    case invalidHTTPResponse
    case httpStatus(Int)

    public var errorDescription: String? {
        switch self {
        case .invalidHTTPResponse: return "GitHub 返回了无效的响应。"
        case .httpStatus(let status): return "检查 GitHub 发布失败（HTTP \(status)）。"
        }
    }
}

public struct GitHubReleaseUpdateChecker: Sendable {
    public typealias Fetch = @Sendable (URLRequest) async throws -> (Data, URLResponse)

    private let owner: String
    private let repository: String
    private let currentVersion: String
    private let fetch: Fetch

    public init(owner: String = AppReleaseIdentity.repositoryOwner,
                repository: String = AppReleaseIdentity.repositoryName,
                currentVersion: String = AppReleaseIdentity.currentVersion,
                fetch: @escaping Fetch = { try await URLSession.shared.data(for: $0) }) {
        self.owner = owner
        self.repository = repository
        self.currentVersion = currentVersion
        self.fetch = fetch
    }

    public func checkForUpdate() async throws -> AppUpdateCheckResult {
        var request = URLRequest(url: URL(string: "https://api.github.com/repos/\(owner)/\(repository)/releases/latest")!)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("\(AppReleaseIdentity.name)/\(currentVersion)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await fetch(request)
        guard let http = response as? HTTPURLResponse else { throw AppUpdateCheckError.invalidHTTPResponse }
        guard (200..<300).contains(http.statusCode) else { throw AppUpdateCheckError.httpStatus(http.statusCode) }

        let release = try JSONDecoder().decode(GitHubLatestRelease.self, from: data)
        let latestVersion = release.tagName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard AppReleaseVersion(latestVersion) > AppReleaseVersion(currentVersion) else {
            return .upToDate(currentVersion: currentVersion, latestVersion: latestVersion)
        }

        let download = Self.preferredDownload(from: release.assets)
        return .updateAvailable(AppUpdateInfo(
            currentVersion: currentVersion,
            latestVersion: latestVersion,
            releaseNotes: release.body?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            releasePageURL: release.htmlURL,
            downloadURL: download?.browserDownloadURL ?? release.htmlURL,
            downloadAssetName: download?.name,
            downloadKind: download.map { Self.kind(of: $0.name) } ?? .other))
    }

    /// 优先带应用名的 DMG，其次带应用名的 zip，再退回任意 DMG / zip。
    static func preferredDownload(from assets: [GitHubReleaseAsset]) -> GitHubReleaseAsset? {
        let named = assets.filter { $0.name.lowercased().contains("xpastepal") }
        for candidates in [named, assets] {
            if let dmg = candidates.first(where: { kind(of: $0.name) == .diskImage }) { return dmg }
            if let zip = candidates.first(where: { kind(of: $0.name) == .applicationZipArchive }) { return zip }
        }
        return nil
    }

    static func kind(of fileName: String) -> AppUpdateDownloadKind {
        let name = fileName.lowercased()
        if name.hasSuffix(".dmg") { return .diskImage }
        if name.hasSuffix(".zip") { return .applicationZipArchive }
        return .other
    }
}

public struct AppReleaseVersion: Comparable, Sendable {
    private let components: [Int]

    public init(_ rawValue: String) {
        var value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.first == "v" || value.first == "V" { value.removeFirst() }
        components = value.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }
    }

    public static func == (lhs: Self, rhs: Self) -> Bool { !(lhs < rhs) && !(rhs < lhs) }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        for index in 0..<max(lhs.components.count, rhs.components.count) {
            let left = index < lhs.components.count ? lhs.components[index] : 0
            let right = index < rhs.components.count ? rhs.components[index] : 0
            if left != right { return left < right }
        }
        return false
    }
}

struct GitHubLatestRelease: Decodable {
    let tagName: String
    let htmlURL: URL
    let body: String?
    let assets: [GitHubReleaseAsset]

    private enum CodingKeys: String, CodingKey {
        case tagName = "tag_name", htmlURL = "html_url", body, assets
    }
}

struct GitHubReleaseAsset: Decodable {
    let name: String
    let browserDownloadURL: URL

    private enum CodingKeys: String, CodingKey {
        case name, browserDownloadURL = "browser_download_url"
    }
}
