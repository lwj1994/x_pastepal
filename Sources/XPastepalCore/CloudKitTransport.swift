import CloudKit
import Foundation
import Security

/// Uses only this application's private CloudKit database and its own custom zone.
actor CloudKitTransport: ClipboardSyncTransport {
    private static let recordType = "SyncEntry"
    private static let maximumPayloadBytes = 256 * 1_024 * 1_024
    private static let maximumTotalBytes = 256 * 1_024 * 1_024
    private static let maximumRecordCount = 100_000
    private static let batchSize = 100

    private let container: CKContainer
    private let database: CKDatabase
    private let environment: String
    private let zoneID = CKRecordZone.ID(zoneName: "XPastepal", ownerName: CKCurrentUserDefaultName)
    private var currentAccountID: String?
    private var serverRecords: [CKRecord.ID: CKRecord] = [:]
    private var cachedEntries: [CKRecord.ID: SyncEntry] = [:]
    private var cachedPayloadSizes: [CKRecord.ID: Int] = [:]
    private var changeToken: CKServerChangeToken?
    private var hasCompleteFetch = false

    /// Check before constructing a CKContainer: an unsigned CLI/ad-hoc app can
    /// raise an Objective-C exception inside CloudKit instead of a Swift error.
    static let configurationError: String? = {
        guard Bundle.main.bundleURL.pathExtension == "app",
              let bundleID = Bundle.main.bundleIdentifier,
              let task = SecTaskCreateFromSelf(nil) else {
            return "iCloud 同步需要运行带有效开发者签名的 XPastepal.app。"
        }
        var code: SecCode?
        guard SecCodeCopySelf([], &code) == errSecSuccess, let code else {
            return "无法验证应用签名；iCloud 同步未启用。"
        }
        guard SecCodeCheckValidity(code, [], nil) == errSecSuccess else {
            return "应用签名验证失败；iCloud 同步未启用。"
        }
        var staticCode: SecStaticCode?
        guard SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess, let staticCode else {
            return "无法读取应用签名；iCloud 同步未启用。"
        }
        var information: CFDictionary?
        guard SecCodeCopySigningInformation(staticCode, SecCSFlags(rawValue: kSecCSSigningInformation), &information) == errSecSuccess,
              let signing = information as? [String: Any],
              let flags = signing[kSecCodeInfoFlags as String] as? NSNumber,
              flags.uint32Value & 0x2 == 0 else { // CS_ADHOC
            return "当前为本地临时签名版本；iCloud 同步需要开发者签名和专用描述文件。"
        }
        func entitlement(_ key: String) -> Any? {
            SecTaskCopyValueForEntitlement(task, key as CFString, nil)
        }
        guard let team = entitlement("com.apple.developer.team-identifier") as? String, !team.isEmpty,
              let applicationID = entitlement("com.apple.application-identifier") as? String,
              applicationID.hasSuffix("." + bundleID) else {
            return "应用缺少有效的 Apple 开发者身份或 App ID 权限。"
        }
        guard let services = entitlement("com.apple.developer.icloud-services") as? [String],
              services.contains("CloudKit"),
              let containers = entitlement("com.apple.developer.icloud-container-identifiers") as? [String],
              containers.contains(containerIdentifier) else {
            return "应用尚未配置自己的 CloudKit 容器，请按 iCloud 配置文档重新签名。"
        }
        guard let environment = entitlement("com.apple.developer.icloud-container-environment") as? String,
              ["Development", "Production"].contains(environment) else {
            return "应用缺少有效的 CloudKit 环境权限。"
        }
        guard FileManager.default.fileExists(
            atPath: Bundle.main.bundleURL.appendingPathComponent("Contents/embedded.provisionprofile").path
        ) else {
            return "应用缺少 iCloud 描述文件，请使用构建脚本完成云签名。"
        }
        return nil
    }()

    private static var containerIdentifier: String {
        Bundle.main.object(forInfoDictionaryKey: "XPastepalCloudKitContainerIdentifier") as? String
            ?? "iCloud.milu.pastepal"
    }

    init() throws {
        if let error = Self.configurationError { throw TransportError.configuration(error) }
        let container = CKContainer(identifier: Self.containerIdentifier)
        self.container = container
        self.database = container.privateCloudDatabase
        let task = SecTaskCreateFromSelf(nil)
        self.environment = task.flatMap {
            SecTaskCopyValueForEntitlement(
                $0, "com.apple.developer.icloud-container-environment" as CFString, nil
            ) as? String
        } ?? ""
    }

    func accountID() async throws -> String {
        switch try await container.accountStatus() {
        case .available:
            break
        case .noAccount:
            throw TransportError.configuration("请先在系统设置中登录 iCloud。")
        case .restricted:
            throw TransportError.configuration("此设备的 iCloud 访问受到限制。")
        case .couldNotDetermine, .temporarilyUnavailable:
            throw TransportError.configuration("iCloud 暂时不可用，请稍后重试。")
        @unknown default:
            throw TransportError.configuration("无法确认 iCloud 账户状态。")
        }
        let recordID = try await container.userRecordID()
        let identifier = "\(Self.containerIdentifier)|\(environment)|\(recordID.recordName)"
        if identifier != currentAccountID {
            resetCache()
            currentAccountID = identifier
        }
        return identifier
    }

    func fetch() async throws -> [SyncEntry] {
        hasCompleteFetch = false
        _ = try await database.save(CKRecordZone(zoneID: zoneID))
        let initialToken = changeToken
        var token = initialToken
        var records = serverRecords
        var entries = cachedEntries
        var payloadSizes = cachedPayloadSizes
        var totalBytes = payloadSizes.values.reduce(0, +)
        do {
            repeat {
                try Task.checkCancellation()
                // Tokens and their complete associated snapshot live only in memory.
                // Restarting the app always rebuilds the snapshot from a nil token.
                let page = try await database.recordZoneChanges(
                    inZoneWith: zoneID, since: token, resultsLimit: Self.batchSize
                )
                defer {
                    for result in page.modificationResultsByID.values {
                        if case .success(let change) = result,
                           let url = (change.record["payload"] as? CKAsset)?.fileURL {
                            try? FileManager.default.removeItem(at: url)
                        }
                    }
                }
                for deletion in page.deletions {
                    records.removeValue(forKey: deletion.recordID)
                    entries.removeValue(forKey: deletion.recordID)
                    totalBytes -= payloadSizes.removeValue(forKey: deletion.recordID) ?? 0
                }
                for (recordID, result) in page.modificationResultsByID {
                    let record = try result.get().record
                    guard record.recordType == Self.recordType,
                          (record["schemaVersion"] as? NSNumber)?.intValue == 1,
                          let asset = record["payload"] as? CKAsset,
                          let fileURL = asset.fileURL else {
                        throw TransportError.invalidRecord
                    }
                    let values = try fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
                    guard values.isRegularFile == true, let size = values.fileSize,
                          size > 0, size <= Self.maximumPayloadBytes else {
                        throw TransportError.payloadLimit
                    }
                    let updatedTotal = totalBytes - (payloadSizes[recordID] ?? 0) + size
                    guard updatedTotal <= Self.maximumTotalBytes else { throw TransportError.payloadLimit }
                    let data = try Data(contentsOf: fileURL, options: .mappedIfSafe)
                    guard data.count == size else { throw TransportError.invalidRecord }
                    let entry = try JSONDecoder().decode(SyncEntry.self, from: data)
                    try entry.validate()
                    guard recordID.recordName == Self.recordName(for: entry) else {
                        throw TransportError.invalidRecord
                    }
                    records[recordID] = record
                    entries[recordID] = entry
                    payloadSizes[recordID] = size
                    totalBytes = updatedTotal
                    guard records.count <= Self.maximumRecordCount else { throw TransportError.payloadLimit }
                }
                token = page.changeToken
                if !page.moreComing { break }
            } while true
            try Task.checkCancellation()
            serverRecords = records
            cachedEntries = entries
            cachedPayloadSizes = payloadSizes
            changeToken = token
            hasCompleteFetch = true
            return entries.values.sorted { Self.recordName(for: $0) < Self.recordName(for: $1) }
        } catch {
            if initialToken != nil, let cloudError = error as? CKError,
               [.changeTokenExpired, .zoneNotFound, .userDeletedZone].contains(cloudError.code) {
                resetCache()
                return try await fetch()
            }
            // Keep the last complete in-memory snapshot and token together. A
            // failed page must never advance just the token or expose half a page.
            throw error
        }
    }

    func push(_ entries: [SyncEntry]) async throws {
        guard hasCompleteFetch else { throw TransportError.fetchRequired }
        guard !entries.isEmpty else { return }
        let expectedAccountID = currentAccountID
        guard entries.count <= Self.maximumRecordCount else { throw TransportError.payloadLimit }
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("XPastepal-CloudKit-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700]
        )
        defer { try? FileManager.default.removeItem(at: directory) }
        do {
            var records: [CKRecord] = []
            var uniqueIDs = Set<CKRecord.ID>()
            var totalBytes = cachedPayloadSizes.values.reduce(0, +)
            var newSizes: [CKRecord.ID: Int] = [:]
            var newEntries: [CKRecord.ID: SyncEntry] = [:]
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            for entry in entries {
                try Task.checkCancellation()
                try entry.validate()
                let recordID = CKRecord.ID(recordName: Self.recordName(for: entry), zoneID: zoneID)
                guard uniqueIDs.insert(recordID).inserted else { throw TransportError.invalidRecord }
                let data = try encoder.encode(entry)
                totalBytes += data.count - (cachedPayloadSizes[recordID] ?? 0)
                guard !data.isEmpty, data.count <= Self.maximumPayloadBytes else {
                    throw TransportError.payloadLimit
                }
                let url = directory.appendingPathComponent(UUID().uuidString + ".json")
                try data.write(to: url, options: .atomic)
                let record = serverRecords[recordID]?.copy() as? CKRecord
                    ?? CKRecord(recordType: Self.recordType, recordID: recordID)
                record["schemaVersion"] = NSNumber(value: 1)
                record["payload"] = CKAsset(fileURL: url)
                records.append(record)
                newSizes[recordID] = data.count
                newEntries[recordID] = entry
            }
            guard totalBytes <= Self.maximumTotalBytes,
                  Set(serverRecords.keys).union(uniqueIDs).count <= Self.maximumRecordCount else {
                throw TransportError.payloadLimit
            }
            for start in stride(from: 0, to: records.count, by: Self.batchSize) {
                try Task.checkCancellation()
                guard try await accountID() == expectedAccountID else {
                    throw SyncError.accountChanged
                }
                try Task.checkCancellation()
                let batch = Array(records[start..<min(start + Self.batchSize, records.count)])
                let result = try await database.modifyRecords(
                    saving: batch, deleting: [], savePolicy: .ifServerRecordUnchanged, atomically: true
                )
                let errors = result.saveResults.values.compactMap { result -> Error? in
                    if case .failure(let error) = result { return error }
                    return nil
                }
                // Preserve the actionable CloudKit error and its retryAfter value.
                if let delayed = errors.max(by: {
                    (($0 as? CKError)?.retryAfterSeconds ?? 0) < (($1 as? CKError)?.retryAfterSeconds ?? 0)
                }), (delayed as? CKError)?.retryAfterSeconds != nil {
                    throw delayed
                }
                if let conflict = errors.first(where: { ($0 as? CKError)?.code == .serverRecordChanged }) {
                    throw conflict
                }
                if let error = errors.first { throw error }
                for record in batch {
                    guard let saved = result.saveResults[record.recordID] else {
                        throw TransportError.incompleteSave
                    }
                    serverRecords[record.recordID] = try saved.get()
                    cachedPayloadSizes[record.recordID] = newSizes[record.recordID]
                    cachedEntries[record.recordID] = newEntries[record.recordID]
                }
            }
        } catch {
            // Never retry a failed save with stale change tags or overwrite a
            // server conflict. The coordinator must refetch, merge, and then push.
            hasCompleteFetch = false
            throw error
        }
    }

    private static func recordName(for entry: SyncEntry) -> String {
        "\(entry.kind.rawValue)-\(entry.id.uuidString)"
    }

    private func resetCache() {
        serverRecords.removeAll()
        cachedEntries.removeAll()
        cachedPayloadSizes.removeAll()
        changeToken = nil
        hasCompleteFetch = false
    }

    private enum TransportError: LocalizedError {
        case configuration(String)
        case invalidRecord
        case payloadLimit
        case fetchRequired
        case incompleteSave

        var errorDescription: String? {
            switch self {
            case .configuration(let message): return message
            case .invalidRecord: return "iCloud 数据格式无效；本轮同步已停止，未跳过任何损坏记录。"
            case .payloadLimit: return "iCloud 数据超过安全限制（总量 256 MB 或 100,000 条）。"
            case .fetchRequired: return "请先完整读取 iCloud 数据，再重试上传。"
            case .incompleteSave: return "iCloud 未确认全部记录已保存，请重新同步。"
            }
        }
    }
}
