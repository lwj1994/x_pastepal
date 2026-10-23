import Foundation

public enum ClipKind: String, Codable, CaseIterable, Sendable {
    case text
    case link
    case image
    case file

    public var title: String {
        switch self {
        case .text: return "文本"
        case .link: return "链接"
        case .image: return "图片"
        case .file: return "文件"
        }
    }

    public var symbol: String {
        switch self {
        case .text: return "text.alignleft"
        case .link: return "link"
        case .image: return "photo"
        case .file: return "doc"
        }
    }
}

public struct ClipItem: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var createdAt: Date
    public var lastCopiedAt: Date
    public var text: String
    public var kind: ClipKind
    public var sourceApp: String
    public var sourceBundleID: String
    public var sourceIconData: Data?
    public var isPinned: Bool
    public var collectionID: UUID?
    public var filePaths: [String]
    public var imageData: Data?
    public var rtfData: Data?

    public init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        lastCopiedAt: Date? = nil,
        text: String,
        kind: ClipKind = .text,
        sourceApp: String = "未知应用",
        sourceBundleID: String = "",
        sourceIconData: Data? = nil,
        isPinned: Bool = false,
        collectionID: UUID? = nil,
        filePaths: [String] = [],
        imageData: Data? = nil,
        rtfData: Data? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.lastCopiedAt = lastCopiedAt ?? createdAt
        self.text = text
        self.kind = kind
        self.sourceApp = sourceApp
        self.sourceBundleID = sourceBundleID
        self.sourceIconData = sourceIconData
        self.isPinned = isPinned
        self.collectionID = collectionID
        self.filePaths = filePaths
        self.imageData = imageData
        self.rtfData = rtfData
    }

    public var title: String {
        switch kind {
        case .image:
            return "复制的图片"
        case .file:
            guard let path = filePaths.first else { return "文件" }
            let name = URL(fileURLWithPath: path).lastPathComponent
            return filePaths.count == 1 ? name : "\(name) 等 \(filePaths.count) 个文件"
        case .text, .link:
            let firstLine = text.split(whereSeparator: \.isNewline).first.map(String.init) ?? text
            let cleanLine = firstLine.trimmingCharacters(in: .whitespacesAndNewlines)
            return cleanLine.isEmpty ? "空白文本" : String(cleanLine.prefix(100))
        }
    }

    public var preview: String {
        switch kind {
        case .image:
            return imageData.map { ByteCountFormatter.string(fromByteCount: Int64($0.count), countStyle: .file) } ?? "图片"
        case .file:
            return filePaths.joined(separator: "\n")
        case .text, .link:
            return String(text.prefix(1_000))
        }
    }
}

public struct ClipCollection: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var symbol: String

    public init(id: UUID = UUID(), name: String, symbol: String = "folder") {
        self.id = id
        self.name = name
        self.symbol = symbol
    }
}
