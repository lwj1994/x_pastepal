import Foundation

public struct LocalBackupInfo: Identifiable, Sendable {
    public let url: URL
    public var id: URL { url }
    public let createdAt: Date
    public let byteCount: Int
    public let reason: String
}

struct LocalBackupStore: Sendable {
    let directory: URL

    private static let filenamePrefix = "xpastepal-backup"
    private static let maximumCount = 30
    private static let maximumTotalBytes = 512 * 1_024 * 1_024

    /// The filename holds non-sensitive metadata, so listing never decodes clipboard contents.
    func list() throws -> [LocalBackupInfo] {
        guard directory.isFileURL else { throw HistoryError.invalidFile("请选择本机备份位置") }
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]
        let urls: [URL]
        do {
            urls = try FileManager.default.contentsOfDirectory(
                at: directory, includingPropertiesForKeys: Array(keys), options: [.skipsHiddenFiles]
            )
        } catch CocoaError.fileReadNoSuchFile {
            return []
        }
        return try urls.compactMap { url in
            guard let metadata = Self.metadata(from: url) else { return nil }
            let values = try url.resourceValues(forKeys: keys)
            guard values.isRegularFile == true, values.isSymbolicLink != true,
                  let size = values.fileSize, size >= 0 else { return nil }
            return LocalBackupInfo(
                // Directory enumeration can resolve /var into /private/var; preserve the
                // caller's base URL so a new archive always has the same identity in list().
                url: directory.appendingPathComponent(url.lastPathComponent),
                createdAt: metadata.createdAt, byteCount: size, reason: metadata.reason
            )
        }.sorted {
            if $0.createdAt != $1.createdAt { return $0.createdAt > $1.createdAt }
            return $0.url.lastPathComponent > $1.url.lastPathComponent
        }
    }

    @discardableResult
    func create(
        _ snapshot: HistorySnapshot,
        reason: String,
        minimumInterval: TimeInterval = 0,
        now: Date = Date()
    ) throws -> LocalBackupInfo? {
        guard directory.isFileURL, Self.isValidReason(reason),
              now.timeIntervalSince1970.isFinite,
              minimumInterval.isFinite, minimumInterval >= 0 else {
            throw HistoryError.invalidFile("备份位置、原因或时间无效")
        }
        let existing = try list()
        if reason == "automatic", minimumInterval > 0,
           let latest = existing.first(where: { $0.reason == "automatic" }),
           now.timeIntervalSince(latest.createdAt) < minimumInterval {
            return nil
        }

        let filename = [
            Self.filenamePrefix, String(now.timeIntervalSince1970), UUID().uuidString, reason
        ].joined(separator: "_") + ".json"
        let url = directory.appendingPathComponent(filename)
        // Validation and the archive size limit are enforced before publishing a new file.
        // The archive writer uses an exclusive 0600 temporary file and an atomic rename.
        try HistoryArchive.write(snapshot, to: url, enforceArchiveLimit: true)
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        let created = LocalBackupInfo(url: url, createdAt: now, byteCount: size, reason: reason)
        try rotate(preserving: created)
        return created
    }

    private func rotate(preserving created: LocalBackupInfo) throws {
        // Always keep the successfully written recovery point, even if the clock moved back.
        let backups = [created] + (try list()).filter { $0.url != created.url }
        var retainedBytes = created.byteCount
        var retainedCount = 1
        var reachedLimit = false
        for backup in backups.dropFirst() {
            if !reachedLimit, retainedCount < Self.maximumCount,
               backup.byteCount <= Self.maximumTotalBytes - min(retainedBytes, Self.maximumTotalBytes) {
                retainedBytes += backup.byteCount
                retainedCount += 1
            } else {
                reachedLimit = true
                try FileManager.default.removeItem(at: backup.url)
            }
        }
    }

    private static func metadata(from url: URL) -> (createdAt: Date, reason: String)? {
        guard url.pathExtension == "json" else { return nil }
        let parts = url.deletingPathExtension().lastPathComponent.split(
            separator: "_", omittingEmptySubsequences: false
        )
        guard parts.count == 4, parts[0] == Substring(filenamePrefix),
              let timestamp = TimeInterval(parts[1]), timestamp.isFinite,
              UUID(uuidString: String(parts[2])) != nil,
              isValidReason(String(parts[3])) else { return nil }
        return (Date(timeIntervalSince1970: timestamp), String(parts[3]))
    }

    private static func isValidReason(_ reason: String) -> Bool {
        guard !reason.isEmpty, reason.utf8.count <= 64 else { return false }
        return reason.utf8.allSatisfy { byte in
            (97...122).contains(byte) || (48...57).contains(byte) || byte == 45
        }
    }
}
