import CryptoKit
import Foundation

enum SyncEntityKind: String, Codable, Sendable {
    case item, collection
}

/// Lamport clocks preserve causal ordering without trusting device wall clocks.
struct SyncStamp: Codable, Equatable, Comparable, Sendable {
    var counter: Int64
    var deviceID: String

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.counter == rhs.counter ? lhs.deviceID < rhs.deviceID : lhs.counter < rhs.counter
    }
}

struct SyncEntry: Codable, Equatable, Sendable {
    var id: UUID
    var kind: SyncEntityKind
    var stamp: SyncStamp
    var item: ClipItem?
    var collection: ClipCollection?

    var isDeleted: Bool { item == nil && collection == nil }
    var key: String { "\(kind.rawValue)-\(id.uuidString)" }

    func validate() throws {
        guard stamp.counter > 0, stamp.counter < Int64.max,
              UUID(uuidString: stamp.deviceID) != nil else { throw SyncError.invalidData }
        if isDeleted { return }
        switch kind {
        case .item:
            guard var item, item.id == id, item.kind != .file, collection == nil else { throw SyncError.invalidData }
            // A collection may arrive in a later page or may already be deleted.
            item.collectionID = nil
            try HistoryArchive.validate(HistorySnapshot(version: 1, items: [item], collections: [],
                                                        maxItems: 500, excludedBundleIDs: "", retentionDays: 0))
        case .collection:
            guard let collection, collection.id == id, item == nil else { throw SyncError.invalidData }
            try HistoryArchive.validate(HistorySnapshot(version: 1, items: [], collections: [collection],
                                                        maxItems: 500, excludedBundleIDs: "", retentionDays: 0))
        }
    }

    fileprivate var digest: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = (try? encoder.encode(Payload(item: item, collection: collection))) ?? Data()
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private struct Payload: Encodable { var item: ClipItem?; var collection: ClipCollection? }
}

struct SyncMetadata: Codable, Sendable {
    var id: UUID
    var kind: SyncEntityKind
    var stamp: SyncStamp
    var deleted: Bool
    var digest: String
    var key: String { "\(kind.rawValue)-\(id.uuidString)" }

    init(_ entry: SyncEntry) {
        id = entry.id; kind = entry.kind; stamp = entry.stamp
        deleted = entry.isDeleted; digest = entry.digest
    }
}

/// Metadata shares the history transaction; payloads are not duplicated on disk.
struct ClipboardSyncState: Codable, Sendable {
    var deviceID = UUID().uuidString
    var counter: Int64 = 0
    var records: [String: SyncMetadata] = [:]

    mutating func reconcile(items: [ClipItem], collections: [ClipCollection],
                            previousItems: [ClipItem] = [], previousCollections: [ClipCollection] = []) {
        let stamp = SyncStamp(counter: min(counter + 1, Int64.max - 1), deviceID: deviceID)
        let oldItems = Dictionary(previousItems.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let oldCollections = Dictionary(previousCollections.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var visible: [String: SyncEntry] = [:]
        for item in items where item.kind != .file {
            let entry = SyncEntry(id: item.id, kind: .item, stamp: stamp, item: item)
            visible[entry.key] = entry
        }
        for collection in collections {
            let entry = SyncEntry(id: collection.id, kind: .collection, stamp: stamp, collection: collection)
            visible[entry.key] = entry
        }
        var changed = false
        for (key, entry) in visible {
            if records[key]?.deleted == false,
               (entry.item != nil && oldItems[entry.id] == entry.item ||
                entry.collection != nil && oldCollections[entry.id] == entry.collection) { continue }
            guard records[key]?.digest != entry.digest || records[key]?.deleted != false else { continue }
            records[key] = SyncMetadata(entry)
            changed = true
        }
        for (key, previous) in records where !previous.deleted && visible[key] == nil {
            records[key] = SyncMetadata(SyncEntry(id: previous.id, kind: previous.kind, stamp: stamp))
            changed = true
        }
        if changed { counter = stamp.counter }
    }

    func entries(items: [ClipItem], collections: [ClipCollection]) -> [SyncEntry] {
        let itemMap = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let collectionMap = Dictionary(collections.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return records.values.map { metadata in
            SyncEntry(id: metadata.id, kind: metadata.kind, stamp: metadata.stamp,
                      item: !metadata.deleted && metadata.kind == .item ? itemMap[metadata.id] : nil,
                      collection: !metadata.deleted && metadata.kind == .collection ? collectionMap[metadata.id] : nil)
        }
    }

    mutating func accept(_ entries: [SyncEntry]) {
        for entry in entries {
            records[entry.key] = SyncMetadata(entry)
            counter = max(counter, entry.stamp.counter)
        }
    }

    func validate(enforceRecordLimit: Bool = true) throws {
        guard UUID(uuidString: deviceID) != nil, counter >= 0, counter < Int64.max,
              (!enforceRecordLimit || records.count <= 100_000) else { throw SyncError.invalidData }
        for (key, record) in records {
            guard key == record.key, record.stamp.counter > 0, record.stamp.counter <= counter,
                  UUID(uuidString: record.stamp.deviceID) != nil else { throw SyncError.invalidData }
        }
    }
}

enum SyncMerge {
    static func merge(_ local: [SyncEntry], _ remote: [SyncEntry]) throws -> [SyncEntry] {
        guard local.count + remote.count <= 200_000 else { throw SyncError.invalidData }
        var result: [String: SyncEntry] = [:]
        for entry in local + remote {
            try entry.validate()
            guard let existing = result[entry.key] else { result[entry.key] = entry; continue }
            // Deletion is permanent for this UUID. Explicit restoration creates a new UUID.
            if entry.isDeleted != existing.isDeleted {
                if entry.isDeleted { result[entry.key] = entry }
            } else if entry.stamp > existing.stamp {
                result[entry.key] = entry
            } else if entry.stamp == existing.stamp && entry != existing {
                throw SyncError.invalidData
            }
        }
        guard result.count <= 100_000 else { throw SyncError.invalidData }
        return result.values.sorted { $0.key < $1.key }
    }
}

protocol ClipboardSyncTransport: Sendable {
    func accountID() async throws -> String
    func fetch() async throws -> [SyncEntry]
    func push(_ entries: [SyncEntry]) async throws
}

enum SyncError: LocalizedError {
    case invalidData, accountChanged, unavailable(String)

    var errorDescription: String? {
        switch self {
        case .invalidData: return "同步数据无效或超过容量限制，已保留本机数据"
        case .accountChanged: return "iCloud 账户已变更。请先关闭同步，确认当前账户后重新启用"
        case .unavailable(let message): return message
        }
    }
}
