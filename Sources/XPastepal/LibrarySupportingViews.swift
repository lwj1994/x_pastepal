import AppKit
import SwiftUI
import XPastepalCore

enum LibrarySheet: Identifiable {
    case collection(ClipCollection?)
    case preview(ClipItem)
    case newText
    case recognizedText(String)

    var id: String {
        switch self {
        case .collection(let collection): return "collection:\(collection?.id.uuidString ?? "new")"
        case .preview(let item): return "preview:\(item.id.uuidString)"
        case .newText: return "newText"
        case .recognizedText: return "recognizedText"
        }
    }
}

struct LibraryCollectionSheet: View {
    let store: ClipboardStore
    let collection: ClipCollection?
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var validationMessage: String?
    @FocusState private var nameIsFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Image(systemName: collection == nil ? "folder.badge.plus" : "folder")
                .font(.system(size: 28)).foregroundStyle(.tint)
            Text(collection == nil ? "新建集合" : "重命名集合")
                .font(.system(size: 20, weight: .semibold))
            TextField("集合名称", text: $name)
                .textFieldStyle(.roundedBorder)
                .focused($nameIsFocused)
                .onSubmit(save)
            if let validationMessage {
                Text(validationMessage).font(.caption).foregroundStyle(.red)
            }
            HStack {
                Spacer()
                Button("取消") { dismiss() }.keyboardShortcut(.cancelAction)
                Button(collection == nil ? "创建" : "保存", action: save)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(28)
        .frame(width: 370)
        .onAppear { name = collection?.name ?? ""; nameIsFocused = true }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard trimmed.utf8.count <= 1_000 else {
            validationMessage = "集合名称过长，请缩短后重试。"
            return
        }
        guard collection != nil || store.collections.count < 1_000 else {
            validationMessage = "集合数量已达到上限，请先整理现有集合。"
            return
        }
        if store.collections.contains(where: {
            $0.id != collection?.id && $0.name.localizedCaseInsensitiveCompare(trimmed) == .orderedSame
        }) {
            validationMessage = "已存在同名集合，请使用其他名称。"
            return
        }
        if let collection {
            guard store.renameCollection(collection, name: trimmed) else { return }
        } else { store.addCollection(name: trimmed) }
        dismiss()
    }
}

struct LibraryTextSheet: View {
    let store: ClipboardStore
    let initialText: String
    let title: String
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var saveError: String?
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title).font(.title2.bold())
            TextEditor(text: $text)
                .font(.system(size: 13))
                .scrollContentBackground(.hidden)
                .padding(10)
                .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                .focused($isFocused)
                .frame(minHeight: 230)
            if let saveError {
                Text(saveError).font(.caption).foregroundStyle(.red)
            }
            HStack {
                Text("\(text.count) 个字符").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("取消") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("保存") { save(copy: false) }.disabled(text.isEmpty)
                Button("保存并复制") { save(copy: true) }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(text.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 570)
        .onAppear { text = initialText; isFocused = true }
    }

    private func save(copy: Bool) {
        saveError = nil
        guard let item = store.addText(text) else {
            saveError = store.errorMessage ?? "保存失败，请检查内容并重试。"
            return
        }
        if copy { store.copy(item) }
        dismiss()
    }
}

struct LibraryPreviewSheet: View {
    let item: ClipItem
    let store: ClipboardStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: ClipPresentation.symbol(for: item)).foregroundStyle(ClipPresentation.color(for: item))
                Text(item.title).font(.headline).lineLimit(1)
                Spacer()
                Button { dismiss() } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.cancelAction)
                    .help("关闭预览")
            }
            .padding(20)
            Divider()
            ScrollView {
                previewContent.padding(24).frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minHeight: 350, maxHeight: 540)
            Divider()
            HStack {
                SourceAppIconView(item: item, size: 16)
                Text(item.sourceApp).foregroundStyle(.secondary)
                Spacer()
                Text(item.createdAt, format: .dateTime.year().month().day().hour().minute())
                    .foregroundStyle(.secondary)
                Button("复制") { store.copy(item); dismiss() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
            .font(.system(size: 11))
            .padding(16)
        }
        .frame(width: 680)
    }

    @ViewBuilder private var previewContent: some View {
        if item.kind == .image, let source = item.imagePreviewSource {
            ClipImageThumbnail(itemID: item.id, source: source, contentMode: .fit, maximumPixelSize: 1600)
                .frame(height: 350)
        } else if item.kind == .file {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(item.filePaths, id: \.self) { path in
                    if let source = ClipImageSource.imageFile(at: path) {
                        ClipImageThumbnail(itemID: item.id, source: source, contentMode: .fit, maximumPixelSize: 1600)
                            .frame(height: 350)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    HStack(spacing: 12) {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: path)).resizable().frame(width: 40, height: 40)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(URL(fileURLWithPath: path).lastPathComponent).font(.headline)
                            Text(path).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                        }
                        Spacer()
                        Button("显示") { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)]) }
                    }
                }
            }
        } else {
            Text(item.text)
                .font(.system(size: 14))
                .lineSpacing(5)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct LibraryListRow: View {
    let item: ClipItem
    let isSelected: Bool
    let onSelect: () -> Void
    let onCopy: () -> Void
    let onToggleFavorite: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            thumbnail.frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title).font(.system(size: 12, weight: .medium)).lineLimit(1)
                HStack(spacing: 5) {
                    SourceAppIconView(item: item, size: 12)
                    Text(item.sourceApp)
                    Text("·")
                    Text(ClipPresentation.label(for: item))
                    if item.kind == .file { Text("· \(item.filePaths.count) 个文件") }
                }
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            Button(action: onToggleFavorite) { FavoriteIcon(isFavorite: item.isPinned).font(.system(size: 10)) }
                .buttonStyle(.plain)
                .help(item.isPinned ? "取消收藏" : "收藏此条内容")
                .accessibilityLabel(item.isPinned ? "取消收藏\(item.title)" : "收藏\(item.title)")
            Text(item.createdAt, style: .relative)
                .font(.system(size: 10)).foregroundStyle(.tertiary).lineLimit(1)
            Button(action: onCopy) { Image(systemName: "doc.on.doc") }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("复制此条内容")
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 10)
        .background(isSelected ? Color.accentColor.opacity(0.12) : Color.primary.opacity(isHovered ? 0.04 : 0.015), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 1.5))
        .contentShape(Rectangle())
        .clipClickActions(onSelect: onSelect, onActivate: onCopy)
        .onHover { isHovered = $0 }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(ClipPresentation.label(for: item))，\(item.title)，来自\(item.sourceApp)")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    @ViewBuilder private var thumbnail: some View {
        if let source = item.imagePreviewSource {
            ClipImageThumbnail(itemID: item.id, source: source)
                .frame(width: 36, height: 36).clipShape(RoundedRectangle(cornerRadius: 5))
        } else {
            Image(systemName: ClipPresentation.symbol(for: item))
                .font(.system(size: 18))
                .foregroundStyle(ClipPresentation.color(for: item))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(ClipPresentation.color(for: item).opacity(0.1), in: RoundedRectangle(cornerRadius: 7))
        }
    }
}

/// 只处理资料库所在窗口的非文本输入，搜索、编辑器和系统文件面板保留原生按键行为。
struct LibraryKeyboardMonitor: NSViewRepresentable {
    let onKeyDown: (NSEvent) -> Bool

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        context.coordinator.view = view
        context.coordinator.onKeyDown = onKeyDown
        context.coordinator.install()
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) { context.coordinator.onKeyDown = onKeyDown }
    func makeCoordinator() -> Coordinator { Coordinator() }
    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) { coordinator.uninstall() }

    @MainActor final class Coordinator {
        weak var view: NSView?
        var onKeyDown: ((NSEvent) -> Bool)?
        private var monitor: Any?

        func install() {
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self, let window = self.view?.window,
                      window.isKeyWindow, event.window === window, window.attachedSheet == nil,
                      !(window.firstResponder is NSTextView), !(window.firstResponder is NSTextField) else { return event }
                return self.onKeyDown?(event) == true ? nil : event
            }
        }

        func uninstall() {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
        }
    }
}
