import AppKit

/// 保存小尺寸 PNG 快照，来源应用退出或卸载后仍能显示原图标。
@MainActor
final class SourceAppIconProvider {
    static let shared = SourceAppIconProvider()
    private let cache = NSCache<NSString, NSData>()

    init() {
        cache.countLimit = 256
        cache.totalCostLimit = 8 * 1_024 * 1_024
    }

    func iconData(for bundleID: String) -> Data? {
        guard !bundleID.isEmpty else { return nil }
        if let cached = cache.object(forKey: bundleID as NSString) { return cached as Data }
        let icon: NSImage?
        if let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first,
           let runningIcon = running.icon {
            icon = runningIcon
        } else if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            icon = NSWorkspace.shared.icon(forFile: url.path)
        } else {
            icon = nil
        }
        guard let icon, let data = Self.pngData(from: icon) else { return nil }
        cache.setObject(data as NSData, forKey: bundleID as NSString, cost: data.count)
        return data
    }

    static func pngData(from icon: NSImage) -> Data? {
        let side = 64
        guard icon.size.width > 0, icon.size.height > 0,
              let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side,
                                            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                            isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
              let context = NSGraphicsContext(bitmapImageRep: bitmap) else { return nil }
        let scale = CGFloat(side) / max(icon.size.width, icon.size.height)
        let size = NSSize(width: icon.size.width * scale, height: icon.size.height * scale)
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        NSGraphicsContext.current = context
        context.imageInterpolation = .high
        context.cgContext.clear(CGRect(x: 0, y: 0, width: side, height: side))
        icon.draw(in: NSRect(x: (CGFloat(side) - size.width) / 2, y: (CGFloat(side) - size.height) / 2,
                            width: size.width, height: size.height),
                  from: .zero, operation: .copy, fraction: 1, respectFlipped: false, hints: nil)
        guard let data = bitmap.representation(using: .png, properties: [:]),
              data.count <= HistoryArchive.maximumSourceIconBytes else { return nil }
        return data
    }
}
