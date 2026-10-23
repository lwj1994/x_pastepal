import AppKit
import SwiftUI
import XPastepalCore

enum ClipPresentation {
    static func label(for item: ClipItem) -> String {
        switch item.kind {
        case .text: return "文字"
        case .link: return "链接"
        case .image: return "图片"
        case .file: return "文件"
        }
    }

    static func symbol(for item: ClipItem) -> String {
        switch item.kind {
        case .text: return "text.alignleft"
        case .link: return "link"
        case .image: return "photo"
        case .file: return "doc"
        }
    }

    static func color(for item: ClipItem) -> Color {
        switch item.kind {
        case .text: return Color(red: 0.31, green: 0.43, blue: 0.90)
        case .link: return Color(red: 0.10, green: 0.58, blue: 0.53)
        case .image: return Color(red: 0.67, green: 0.38, blue: 0.83)
        case .file: return Color(red: 0.78, green: 0.48, blue: 0.13)
        }
    }
}

struct FavoriteIcon: View {
    let isFavorite: Bool

    var body: some View {
        Image(systemName: isFavorite ? "heart.fill" : "heart")
            .foregroundStyle(isFavorite ? Color.red : Color.gray)
            .accessibilityLabel(isFavorite ? "已收藏" : "未收藏")
    }
}

struct ClipCard: View {
    static let minimumAspectRatio: CGFloat = 3.0 / 4.0
    static let maximumAspectRatio: CGFloat = 4.0 / 3.0

    let item: ClipItem
    let isSelected: Bool
    let onSelect: () -> Void
    let onCopy: () -> Void
    var aspectRatio: CGFloat = maximumAspectRatio

    @State private var isHovered = false

    var body: some View {
        // Content must not change the size reserved by the surrounding stack or grid.
        Color.clear
            .aspectRatio(min(Self.maximumAspectRatio, max(Self.minimumAspectRatio, aspectRatio)), contentMode: .fit)
            .overlay { content.padding(14) }
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(isSelected ? Color.accentColor : Color.primary.opacity(isHovered ? 0.15 : 0.07), lineWidth: isSelected ? 2 : 1)
            }
            .shadow(color: .black.opacity(isSelected ? 0.06 : 0.025), radius: 7, x: 0, y: 3)
            .contentShape(RoundedRectangle(cornerRadius: 14))
            .clipClickActions(onSelect: onSelect, onActivate: onCopy)
            .onHover { isHovered = $0 }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("\(ClipPresentation.label(for: item))，\(item.title)，来自\(item.sourceApp)")
            .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 7) {
                Image(systemName: ClipPresentation.symbol(for: item))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(ClipPresentation.color(for: item))
                    .frame(width: 25, height: 25)
                    .background(ClipPresentation.color(for: item).opacity(0.12), in: RoundedRectangle(cornerRadius: 7))
                Text(ClipPresentation.label(for: item))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 4)
                FavoriteIcon(isFavorite: item.isPinned)
                    .font(.system(size: 10))
                Button(action: onCopy) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 11, weight: .medium))
                        .frame(width: 25, height: 25)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .background(isHovered ? Color.primary.opacity(0.05) : .clear, in: RoundedRectangle(cornerRadius: 6))
                .help("复制此条内容")
                .accessibilityLabel("复制\(item.title)")
            }

            cardContent
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .clipped()

            HStack(spacing: 5) {
                SourceAppIconView(item: item)
                Text(item.sourceApp)
                    .lineLimit(1)
                Spacer(minLength: 3)
                Text(item.createdAt, style: .relative)
                    .lineLimit(1)
            }
            .font(.system(size: 10))
            .foregroundStyle(.tertiary)
        }
    }

    @ViewBuilder private var cardContent: some View {
        if let source = item.imagePreviewSource {
            VStack(alignment: .leading, spacing: 4) {
                ClipImageThumbnail(itemID: item.id, source: source)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                if item.kind == .file {
                    Text(item.title).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
                }
            }
        } else if item.kind == .file {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: item.filePaths.count > 1 ? "doc.on.doc.fill" : "doc.fill")
                    .font(.system(size: 29))
                    .foregroundStyle(ClipPresentation.color(for: item).opacity(0.7))
                VStack(alignment: .leading, spacing: 5) {
                    Text(item.title)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(2)
                    Text("\(item.filePaths.count) 个文件")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 7)
        } else {
            Text(item.preview)
                .font(.system(size: 12, weight: item.kind == .link ? .medium : .regular))
                .foregroundStyle(item.kind == .link ? ClipPresentation.color(for: item) : .primary)
                .lineSpacing(4)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
