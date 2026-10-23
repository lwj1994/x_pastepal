import SwiftUI
import XPastepalCore

struct SourceAppIconView: View {
    let item: ClipItem
    var size: CGFloat = 14
    @State private var image: CGImage?
    @State private var loadedData: Data?

    var body: some View {
        Group {
            if loadedData == item.sourceIconData, let image {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .renderingMode(.original)
                    .scaledToFit()
            } else {
                Image(systemName: "app")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
        .task(id: item.sourceIconData) {
            let data = item.sourceIconData
            let thumbnail: CGImage?
            if let data {
                thumbnail = await ClipThumbnailCache.shared.image(for: item.id, source: .data(data), maximumPixelSize: 64)
            } else {
                thumbnail = nil
            }
            guard !Task.isCancelled else { return }
            image = thumbnail
            loadedData = data
        }
    }
}
