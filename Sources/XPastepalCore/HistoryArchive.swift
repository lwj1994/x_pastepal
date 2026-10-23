import CryptoKit
import Darwin
import Foundation

struct HistorySnapshot: Codable, Sendable {
    var version: Int
    var items: [ClipItem]
    var collections: [ClipCollection]
    var maxItems: Int
    var excludedBundleIDs: String
    var retentionDays: Int
    // 可选字段允许读取增加此设置之前保存的历史文件。
    var monitoringEnabled: Bool?
    var syncState: ClipboardSyncState?
    var cloudSyncEnabled: Bool?
    var cloudAccountID: String?
    var automaticBackupEnabled: Bool?
    var backupIntervalHours: Int?
}

enum HistoryError: LocalizedError {
    case unsupportedVersion
    case invalidFile(String)
    case archiveTooLarge
    case historyTooLarge
    case storageUnavailable
    case writeFailed(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedVersion: return "历史文件来自不支持的版本"
        case let .invalidFile(reason): return "历史文件无效：\(reason)"
        case .archiveTooLarge: return "历史文件超过 256 MB 的导入导出上限"
        case .historyTooLarge: return "合并后的历史超过 20,000 条或 1,000 个收藏夹，请先整理后再导入"
        case .storageUnavailable: return "当前历史文件损坏，已保留原文件；修复后才能导入"
        case let .writeFailed(message): return "历史记录保存失败：\(message)"
        }
    }
}

enum HistoryArchive {
    static let maximumFileBytes = 256 * 1_024 * 1_024
    static let maximumPayloadBytes = 25 * 1_024 * 1_024
    static let maximumSourceIconBytes = 64 * 1_024
    static let maximumCombinedPayloadBytes = 160 * 1_024 * 1_024

    static func read(from url: URL) throws -> HistorySnapshot {
        guard url.isFileURL else { throw HistoryError.invalidFile("请选择本机 JSON 文件") }
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
        guard values.isRegularFile == true else { throw HistoryError.invalidFile("请选择普通文件") }
        guard let size = values.fileSize, size <= maximumFileBytes else { throw HistoryError.archiveTooLarge }
        // 按块读取并再次检查上限，防止读取期间文件增长导致无界分配。
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var data = Data()
        while let chunk = try handle.read(upToCount: 1_024 * 1_024), !chunk.isEmpty {
            guard data.count + chunk.count <= maximumFileBytes else { throw HistoryError.archiveTooLarge }
            data.append(chunk)
        }
        let snapshot = try JSONDecoder().decode(HistorySnapshot.self, from: data)
        try validate(snapshot)
        return snapshot
    }

    static func validate(_ snapshot: HistorySnapshot, enforceArchiveLimits: Bool = true) throws {
        guard snapshot.version == 1 else { throw HistoryError.unsupportedVersion }
        try snapshot.syncState?.validate(enforceRecordLimit: enforceArchiveLimits)
        guard (!enforceArchiveLimits || snapshot.items.count <= 20_000 && snapshot.collections.count <= 1_000),
              (1...20_000).contains(snapshot.maxItems), (0...36_500).contains(snapshot.retentionDays),
              snapshot.excludedBundleIDs.utf8.count <= 100_000 else {
            throw HistoryError.invalidFile("记录数量或设置超出范围")
        }
        let collectionIDs = Set(snapshot.collections.map(\.id))
        guard collectionIDs.count == snapshot.collections.count,
              Set(snapshot.items.map(\.id)).count == snapshot.items.count else {
            throw HistoryError.invalidFile("包含重复的记录或收藏夹 ID")
        }
        for collection in snapshot.collections {
            guard !collection.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  collection.name.utf8.count <= 1_000, collection.symbol.utf8.count <= 200 else {
                throw HistoryError.invalidFile("收藏夹名称或图标无效")
            }
        }
        var totalBytes = 0
        for item in snapshot.items {
            let bytes = payloadBytes(item)
            totalBytes += bytes
            guard item.text.utf8.count <= maximumPayloadBytes,
                  (item.imageData?.count ?? 0) <= maximumPayloadBytes,
                  (item.rtfData?.count ?? 0) <= maximumPayloadBytes,
                  (item.sourceIconData?.count ?? 0) <= maximumSourceIconBytes,
                  (!enforceArchiveLimits || totalBytes <= maximumCombinedPayloadBytes) else {
                throw HistoryError.archiveTooLarge
            }
            guard item.sourceApp.utf8.count <= 1_000, item.sourceBundleID.utf8.count <= 1_000,
                  item.filePaths.count <= 10_000,
                  item.filePaths.allSatisfy({ $0.utf8.count <= 16_384 && $0.hasPrefix("/") && !$0.contains("\0") }),
                  item.collectionID.map(collectionIDs.contains) ?? true,
                  item.createdAt.timeIntervalSinceReferenceDate.isFinite,
                  item.lastCopiedAt.timeIntervalSinceReferenceDate.isFinite else {
                throw HistoryError.invalidFile("记录的来源、日期、文件路径或收藏夹引用无效")
            }
            switch item.kind {
            case .text, .link:
                guard !item.text.isEmpty else { throw HistoryError.invalidFile("文本记录为空") }
            case .image:
                guard let image = item.imageData, !image.isEmpty else { throw HistoryError.invalidFile("图片记录缺少图片数据") }
            case .file:
                guard !item.filePaths.isEmpty else { throw HistoryError.invalidFile("文件记录缺少路径") }
            }
        }
    }

    static func payloadBytes(_ item: ClipItem) -> Int {
        let contentBytes = item.text.utf8.count + (item.imageData?.count ?? 0) + (item.rtfData?.count ?? 0)
        let filePathBytes = item.filePaths.reduce(0) { $0 + $1.utf8.count }
        return contentBytes + filePathBytes + (item.sourceIconData?.count ?? 0)
    }

    /// 以内容摘要去重，避免对大型图片历史进行两两比较。
    static func contentKey(_ item: ClipItem) -> String {
        var digest = SHA256()
        digest.update(data: Data(item.kind.rawValue.utf8))
        switch item.kind {
        case .text, .link: digest.update(data: Data(item.text.utf8))
        case .image: digest.update(data: item.imageData ?? Data())
        case .file:
            for path in item.filePaths.sorted() {
                digest.update(data: Data(path.utf8))
                digest.update(data: Data([0]))
            }
        }
        return digest.finalize().map { String(format: "%02x", $0) }.joined()
    }

    static func write(_ snapshot: HistorySnapshot, to url: URL, enforceArchiveLimit: Bool) throws {
        guard url.isFileURL else { throw HistoryError.invalidFile("请选择本机文件位置") }
        if enforceArchiveLimit { try validate(snapshot) }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(snapshot)
        if enforceArchiveLimit, data.count > maximumFileBytes { throw HistoryError.archiveTooLarge }
        let parent = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o700])
        let temporary = parent.appendingPathComponent(".xpastepal-\(UUID().uuidString).tmp")
        let descriptor = Darwin.open(temporary.path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, 0o600)
        guard descriptor >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        defer {
            try? handle.close()
            try? FileManager.default.removeItem(at: temporary)
        }
        try handle.write(contentsOf: data)
        try handle.synchronize()
        try handle.close()
        guard Darwin.rename(temporary.path, url.path) == 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
    }
}
