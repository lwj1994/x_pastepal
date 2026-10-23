import AppKit
import ImageIO
import SwiftUI
import UniformTypeIdentifiers
import XPastepalCore

enum ClipImageSource: Equatable, Sendable {
    case data(Data)
    case file(URL)

    static func imageFile(at path: String) -> ClipImageSource? {
        let url = URL(fileURLWithPath: path)
        guard UTType(filenameExtension: url.pathExtension)?.conforms(to: .image) == true else { return nil }
        return .file(url)
    }
}

extension ClipItem {
    var imagePreviewSource: ClipImageSource? {
        if kind == .image, let imageData { return .data(imageData) }
        if kind == .file, let path = filePaths.first { return ClipImageSource.imageFile(at: path) }
        return nil
    }
}

struct ClipImageThumbnail: View {
    let itemID: UUID
    let source: ClipImageSource
    var contentMode: ContentMode = .fill
    var maximumPixelSize = 640
    @State private var image: CGImage?
    @State private var loadedRequest: Request?

    private struct Request: Equatable {
        let itemID: UUID
        let source: ClipImageSource
        let maximumPixelSize: Int
    }

    private var request: Request {
        Request(itemID: itemID, source: source, maximumPixelSize: maximumPixelSize)
    }

    var body: some View {
        Color.secondary.opacity(0.08)
        .overlay {
            if loadedRequest == request, let image {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                VStack(spacing: 5) {
                    Image(systemName: "photo")
                    if loadedRequest == request { Text("无法预览图片").font(.caption2) }
                }
                .foregroundStyle(.secondary)
            }
        }
        .clipped()
        .accessibilityLabel("图片预览")
        .task(id: request) {
            let current = request
            let thumbnail = await ClipThumbnailCache.shared.image(
                for: current.itemID, source: current.source, maximumPixelSize: current.maximumPixelSize)
            guard !Task.isCancelled else { return }
            image = thumbnail
            loadedRequest = current
        }
    }
}

/// File access and ImageIO decoding stay off the UI actor.
actor ClipThumbnailCache {
    static let shared = ClipThumbnailCache()
    private let cache = NSCache<NSString, Entry>()

    private struct FileRevision: Equatable {
        let modificationDate: Date?
        let size: Int?
    }

    init() {
        cache.totalCostLimit = 32 * 1_024 * 1_024
        cache.countLimit = 200
    }

    func image(for id: UUID, source: ClipImageSource, maximumPixelSize: Int = 640) -> CGImage? {
        let fileRevision: FileRevision?
        let sourceKey: String
        let sourceCost: Int
        switch source {
        case .data(let data):
            fileRevision = nil
            sourceKey = "data"
            sourceCost = data.count
        case .file(let url):
            var fileURL = url
            fileURL.removeAllCachedResourceValues()
            guard url.isFileURL,
                  let values = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey, .isRegularFileKey]),
                  values.isRegularFile == true else { return nil }
            fileRevision = FileRevision(modificationDate: values.contentModificationDate, size: values.fileSize)
            sourceKey = url.path
            sourceCost = 0
        }
        let key = "\(id.uuidString)/\(maximumPixelSize)/\(sourceKey)" as NSString
        if let entry = cache.object(forKey: key), entry.source == source, entry.fileRevision == fileRevision {
            return entry.image
        }
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        let imageSource: CGImageSource?
        switch source {
        case .data(let data): imageSource = CGImageSourceCreateWithData(data as CFData, options)
        case .file(let url): imageSource = CGImageSourceCreateWithURL(url as CFURL, options)
        }
        guard let imageSource,
              let image = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceThumbnailMaxPixelSize: maximumPixelSize
              ] as CFDictionary) else { return nil }
        cache.setObject(Entry(source: source, fileRevision: fileRevision, image: image), forKey: key,
                        cost: image.bytesPerRow * image.height + sourceCost)
        return image
    }

    private final class Entry {
        let source: ClipImageSource
        let fileRevision: FileRevision?
        let image: CGImage
        init(source: ClipImageSource, fileRevision: FileRevision?, image: CGImage) {
            self.source = source
            self.fileRevision = fileRevision
            self.image = image
        }
    }
}
