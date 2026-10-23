import AppKit
import SwiftUI
import XPastepalCore

struct LibraryClipDetailView: View {
    let item: ClipItem
    let store: ClipboardStore
    let isWorking: Bool
    let onRecognize: () -> Void
    let onPreview: () -> Void
    let onTransform: (TextTransformation) -> Void
    @State private var editedText = ""
    @State private var isEditing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("内容详情")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Button(action: onPreview) { Image(systemName: "arrow.up.left.and.arrow.down.right") }
                    .buttonStyle(.plain)
                    .help("放大预览（空格）")
                Button { store.togglePin(item) } label: {
                    FavoriteIcon(isFavorite: item.isPinned)
                }
                .buttonStyle(.plain)
                .help(item.isPinned ? "取消收藏" : "收藏此条内容")
            }
            .padding(.horizontal, 20)
            .padding(.top, 29)
            .padding(.bottom, 26)

            ScrollView {
                VStack(alignment: .leading, spacing: 19) {
                    HStack(spacing: 9) {
                        Image(systemName: ClipPresentation.symbol(for: item))
                            .font(.system(size: 16))
                            .foregroundStyle(ClipPresentation.color(for: item))
                            .frame(width: 38, height: 38)
                            .background(ClipPresentation.color(for: item).opacity(0.10), in: RoundedRectangle(cornerRadius: 11))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(ClipPresentation.label(for: item))
                                .font(.system(size: 13, weight: .semibold))
                            HStack(spacing: 4) {
                                SourceAppIconView(item: item)
                                Text(item.sourceApp)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    preview

                    if item.kind == .image {
                        Button(action: onRecognize) {
                            Label("识别图片中的文字", systemImage: "text.viewfinder")
                                .frame(maxWidth: .infinity)
                        }
                        .disabled(isWorking)
                        .buttonStyle(.bordered)
                    }
                    if item.kind == .text || item.kind == .link {
                        Menu {
                            ForEach(TextTransformation.allCases) { transformation in
                                Button(transformation.title) { onTransform(transformation) }
                            }
                        } label: {
                            Label("文本转换", systemImage: "textformat.abc")
                        }
                    }
                    if item.kind == .link, let url = URL(string: item.text.trimmingCharacters(in: .whitespacesAndNewlines)) {
                        Button { NSWorkspace.shared.open(url) } label: { Label("在浏览器中打开", systemImage: "safari") }
                            .buttonStyle(.link)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("信息").font(.system(size: 10, weight: .semibold)).foregroundStyle(.tertiary)
                        metadataRow("来源", value: item.sourceApp)
                        metadataRow("记录时间", value: item.createdAt.formatted(date: .abbreviated, time: .shortened))
                        if !item.text.isEmpty {
                            metadataRow("字符数", value: item.text.count.formatted())
                        }
                        if item.kind == .file {
                            metadataRow("文件数", value: item.filePaths.count.formatted())
                        }
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("所属集合").font(.system(size: 10, weight: .semibold)).foregroundStyle(.tertiary)
                        Menu {
                            if item.collectionID != nil {
                                Button("从集合移除") { store.move(item, to: nil) }
                            }
                            ForEach(store.collections) { collection in
                                Button(collection.name) { store.move(item, to: collection.id) }
                            }
                        } label: {
                            HStack {
                                Image(systemName: "folder")
                                Text(store.collections.first { $0.id == item.collectionID }?.name ?? "选择集合")
                                Spacer()
                                Image(systemName: "chevron.down").font(.system(size: 9))
                            }
                            .font(.system(size: 11))
                            .padding(10)
                            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
                        }
                        .menuStyle(.borderlessButton)
                        .menuIndicator(.hidden)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }

            VStack(spacing: 9) {
                Button { store.copy(item) } label: {
                    Label("复制内容", systemImage: "doc.on.doc")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                }
                .buttonStyle(.borderedProminent)
                .help("复制选中的内容（回车）")
                HStack(spacing: 9) {
                    Button { store.copy(item, plainText: true) } label: {
                        Text("复制纯文本").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(item.text.isEmpty)
                    .help("去除格式后复制")
                    Button(role: .destructive) { store.delete(item) } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.bordered)
                    .help("删除此条内容")
                }
            }
            .controlSize(.regular)
            .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.25))
    }

    @ViewBuilder private var preview: some View {
        if item.kind == .image, let source = item.imagePreviewSource {
            ClipImageThumbnail(itemID: item.id, source: source, contentMode: .fit)
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: 9))
        } else if item.kind == .file {
            VStack(alignment: .leading, spacing: 9) {
                ForEach(item.filePaths, id: \.self) { path in
                    if let source = ClipImageSource.imageFile(at: path) {
                        ClipImageThumbnail(itemID: item.id, source: source, contentMode: .fit)
                            .frame(height: 180)
                            .clipShape(RoundedRectangle(cornerRadius: 9))
                    }
                    Label(URL(fileURLWithPath: path).lastPathComponent, systemImage: "doc")
                        .font(.system(size: 11))
                        .lineLimit(2)
                        .help(path)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(13)
            .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 10))
        } else {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(isEditing ? "编辑内容" : "内容预览")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.tertiary)
                    Spacer()
                    Button(isEditing ? "保存" : "编辑") {
                        if isEditing {
                            store.updateText(item, text: editedText)
                            isEditing = false
                        } else {
                            editedText = item.text
                            isEditing = true
                        }
                    }
                    .font(.system(size: 10))
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentColor)
                    .disabled(isEditing && editedText.isEmpty)
                    .help(isEditing ? "保存文字修改" : "编辑此条文字")
                }
                if isEditing {
                    TextEditor(text: $editedText)
                        .font(.system(size: 12))
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 150)
                        .padding(8)
                        .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                    Button("取消编辑") { isEditing = false }
                        .font(.system(size: 10))
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                } else {
                    Text(item.text.isEmpty ? item.preview : item.text)
                        .font(.system(size: 12))
                        .lineSpacing(5)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(13)
                        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    private func metadataRow(_ title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(title).foregroundStyle(.secondary)
            Spacer(minLength: 5)
            Text(value).multilineTextAlignment(.trailing).textSelection(.enabled)
        }
        .font(.system(size: 10))
    }
}

