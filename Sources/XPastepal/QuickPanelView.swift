import AppKit
import Carbon
import SwiftUI
import XPastepalCore

struct QuickPanelView: View {
    @Bindable var store: ClipboardStore
    var coordinator: AppCoordinator
    @State private var query = ""
    @State private var selectedIDs: Set<UUID> = []
    @State private var focusedID: UUID?
    @State private var selectionAnchor: UUID?
    @State private var collectionID: UUID?
    @State private var kind: ClipKind?
    @State private var pinnedOnly = false
    @State private var previewItem: ClipItem?
    @FocusState private var searchFocused: Bool
    private var vertical: Bool { coordinator.panelPreferences.position.isVertical }
    private var items: [ClipItem] {
        Array(store.filteredItems(query: query, kind: kind, collectionID: collectionID, pinnedOnly: pinnedOnly).prefix(200))
    }
    private var selected: ClipItem? { items.first(where: { $0.id == focusedID }) ?? items.first }
    private var chosen: [ClipItem] {
        let matches = items.filter { selectedIDs.contains($0.id) }
        return matches.isEmpty ? selected.map { [$0] } ?? [] : matches
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            filterBar
            Divider()
            if items.isEmpty { emptyView } else { cards }
            Divider()
            footer
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .background(PanelKeyboardMonitor(onKeyDown: handleKey))
        .onAppear { searchFocused = true; resetSelection() }
        .onChange(of: query) { _, _ in resetSelection() }
        .onChange(of: collectionID) { _, _ in resetSelection() }
        .onChange(of: kind) { _, _ in resetSelection() }
        .onChange(of: pinnedOnly) { _, _ in resetSelection() }
        .onChange(of: items.map(\.id)) { _, ids in
            selectedIDs.formIntersection(ids)
            if let focusedID, !ids.contains(focusedID) { resetSelection() }
        }
        .popover(item: $previewItem) { item in LibraryPreviewSheet(item: item, store: store) }
    }

    private var header: some View {
        HStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "square.on.square.fill")
                    .font(.system(size: 18, weight: .semibold))
                if !vertical { Text("XPastepal").font(.system(size: 13, weight: .semibold)) }
            }
            .frame(width: vertical ? 28 : 126, height: 28)
            if !vertical { Divider().frame(height: 20) }
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("搜索剪贴板历史…", text: $query)
                .textFieldStyle(.plain).focused($searchFocused)
                .accessibilityLabel("搜索剪贴板历史")
            if !query.isEmpty {
                Button { query = "" } label: { Image(systemName: "xmark.circle.fill") }
                    .help("清空搜索")
            }
            if !vertical { Text(coordinator.shortcutLabel).font(.caption.monospaced()).foregroundStyle(.secondary) }
            Button {
                coordinator.panelPreferences.staysOpen.toggle()
            } label: {
                Image(systemName: coordinator.panelPreferences.staysOpen ? "pin.fill" : "pin")
                    .foregroundStyle(coordinator.panelPreferences.staysOpen ? Color.accentColor : .secondary)
            }.help(coordinator.panelPreferences.staysOpen ? "取消保持展开" : "保持展开：点击其他应用时保留面板")
                .accessibilityLabel("保持展开")
            Menu {
                Button("打开资料库") { coordinator.showLibrary() }
                Button("设置…") { coordinator.showSettings() }
                Divider()
                ForEach(PanelPosition.allCases) { position in
                    Button(position.title) {
                        coordinator.panelPreferences.position = position
                        coordinator.positionPanel()
                    }
                }
            } label: { Image(systemName: "ellipsis.circle") }.menuStyle(.borderlessButton).fixedSize()
                .help("面板选项")
            Button { coordinator.dismissPanel() } label: { Image(systemName: "xmark") }
                .help("关闭 · Esc").accessibilityLabel("关闭快捷面板")
        }.buttonStyle(.borderless).padding(.horizontal, 18).padding(.vertical, 15)
    }

    private var filterBar: some View {
        HStack(spacing: 8) {
            Menu {
                Button("全部内容") { collectionID = nil; pinnedOnly = false }
                Button { collectionID = nil; pinnedOnly = true } label: {
                    Label { Text("收藏") } icon: { FavoriteIcon(isFavorite: pinnedOnly) }
                }
                Divider()
                ForEach(store.collections) { collection in
                    Button(collection.name) { collectionID = collection.id; pinnedOnly = false }
                }
            } label: {
                Label {
                    Text(pinnedOnly ? "收藏" : store.collections.first(where: { $0.id == collectionID })?.name ?? "全部内容")
                } icon: {
                    if pinnedOnly { FavoriteIcon(isFavorite: true) } else { Image(systemName: "folder") }
                }
            }.fixedSize().help("切换集合 · ⌘[ / ⌘]")
            Picker("类型", selection: $kind) {
                Text("全部类型").tag(ClipKind?.none)
                ForEach(ClipKind.allCases, id: \.self) { kind in Text(kind.title).tag(Optional(kind)) }
            }.labelsHidden().frame(maxWidth: 110)
            Spacer(minLength: 0)
            if selectedIDs.count > 1 {
                Button("复制 \(selectedIDs.count) 项") { store.copyItems(chosen) }.font(.caption)
            }
            Text("\(items.count) 项").font(.caption).foregroundStyle(.secondary)
        }.controlSize(.small).padding(.horizontal, 18).padding(.bottom, 10)
    }

    private var cards: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView(vertical ? .vertical : .horizontal) {
                    if vertical {
                        LazyVStack(spacing: 12) { ForEach(items) { item in card(item) } }
                            .padding(14)
                    } else {
                        let height = max(1, geometry.size.height - 24)
                        let aspectRatio = min(ClipCard.maximumAspectRatio,
                                              max(ClipCard.minimumAspectRatio, coordinator.panelPreferences.cardWidth / height))
                        LazyHStack(spacing: 12) {
                            ForEach(items) { item in
                                card(item, aspectRatio: aspectRatio)
                                    .frame(width: height * aspectRatio, height: height)
                            }
                        }
                        .padding(.horizontal, 18).padding(.vertical, 12)
                    }
                }
                .onChange(of: focusedID) { _, id in
                    if let id { withAnimation(.easeOut(duration: 0.12)) { proxy.scrollTo(id) } }
                }
            }
        }
    }

    private func card(_ item: ClipItem, aspectRatio: CGFloat = ClipCard.maximumAspectRatio) -> some View {
        ClipCard(item: item, isSelected: selectedIDs.contains(item.id),
                 onSelect: { select(item) }, onCopy: { coordinator.paste(item) }, aspectRatio: aspectRatio)
            .id(item.id)
            .contextMenu {
                Button("粘贴") { coordinator.paste(item) }
                Button("粘贴为纯文本") { coordinator.paste(item, plainText: true) }.disabled(item.text.isEmpty)
                Button("仅复制") { store.copy(item) }
                Button("预览") { previewItem = item }
                Divider()
                Button { store.togglePin(item) } label: {
                    Label { Text(item.isPinned ? "取消收藏" : "收藏") } icon: { FavoriteIcon(isFavorite: item.isPinned) }
                }
                Menu("移入集合") {
                    if item.collectionID != nil {
                        Button("从集合移除") { store.move(item, to: nil) }
                    }
                    ForEach(store.collections) { collection in
                        Button(collection.name) { store.move(item, to: collection.id) }
                    }
                }
                Button("删除", role: .destructive) { store.delete(item) }
            }
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: query.isEmpty ? "doc.on.clipboard" : "magnifyingglass").font(.system(size: 32)).foregroundStyle(.teal)
            Text(query.isEmpty ? "这里还没有内容" : "没有找到匹配内容").font(.headline)
            Text(query.isEmpty ? "复制文字、链接、图片或文件后再次呼出" : "试试其他关键词或分类")
                .foregroundStyle(.secondary).multilineTextAlignment(.center).font(.caption)
        }.padding(20).frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 7) {
                Circle().fill(store.isMonitoring ? Color.green : .orange).frame(width: 6, height: 6)
                Text(coordinator.pasteMessage ?? store.errorMessage ?? (store.isMonitoring ? "正在记录" : "已暂停记录")).lineLimit(vertical ? 3 : 1)
                Spacer(minLength: 0)
                if !vertical { Text("方向键选择   ↩ 粘贴   ⇧↩ 纯文本   空格预览   ⌘1–9 快速粘贴   Esc 关闭") }
            }
            if vertical { Text("↩ 粘贴 · ⇧↩ 纯文本 · 空格预览 · Esc 关闭") }
        }.font(.system(size: 10)).foregroundStyle(.secondary).padding(.horizontal, 18).padding(.vertical, 11)
    }

    private func resetSelection() {
        focusedID = items.first?.id
        selectedIDs = Set(items.prefix(1).map(\.id))
        selectionAnchor = focusedID
    }

    private func select(_ item: ClipItem) {
        let flags = NSEvent.modifierFlags
        if flags.contains(.shift), let anchor = items.firstIndex(where: { $0.id == selectionAnchor }), let end = items.firstIndex(where: { $0.id == item.id }) {
            let range = Set(items[min(anchor, end)...max(anchor, end)].map(\.id))
            selectedIDs = flags.contains(.command) ? selectedIDs.union(range) : range
        } else if flags.contains(.command) {
            if selectedIDs.contains(item.id) { selectedIDs.remove(item.id) } else { selectedIDs.insert(item.id) }
        } else { selectedIDs = [item.id]; selectionAnchor = item.id }
        focusedID = item.id
        searchFocused = false
    }

    private func moveSelection(_ offset: Int, extend: Bool) {
        guard !items.isEmpty else { return }
        let index = items.firstIndex(where: { $0.id == focusedID }) ?? 0
        let id = items[max(0, min(items.count - 1, index + offset))].id
        focusedID = id
        if extend, let anchor = items.firstIndex(where: { $0.id == selectionAnchor }), let end = items.firstIndex(where: { $0.id == id }) {
            selectedIDs = Set(items[min(anchor, end)...max(anchor, end)].map(\.id))
        } else { selectedIDs = [id]; selectionAnchor = id }
        searchFocused = false
    }

    private func handleKey(_ event: NSEvent) -> Bool {
        guard previewItem == nil else { return false }
        if let client = event.window?.firstResponder as? NSTextInputClient, client.hasMarkedText() { return false }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let command = flags.contains(.command)
        if command, let char = event.charactersIgnoringModifiers?.lowercased() {
            if char == "f" { searchFocused = true; return true }
            if char == "c", !searchFocused { store.copyItems(chosen); return true }
            if char == "a", !searchFocused { selectedIDs = Set(items.map(\.id)); return true }
            if let number = Int(char), (1...9).contains(number), items.count >= number {
                coordinator.paste(items[number - 1]); return true
            }
            if char == "[" || char == "]" {
                let ids: [UUID?] = [nil] + store.collections.map { Optional($0.id) }
                let index = ids.firstIndex(of: collectionID) ?? 0
                collectionID = ids[(index + (char == "]" ? 1 : ids.count - 1)) % ids.count]
                pinnedOnly = false; return true
            }
            return false
        }
        guard !flags.contains(.control), !flags.contains(.option) else { return false }
        switch Int(event.keyCode) {
        case kVK_Escape: coordinator.dismissPanel(); return true
        case kVK_Return, kVK_ANSI_KeypadEnter:
            coordinator.pasteItems(chosen, plainText: flags.contains(.shift)); return true
        case kVK_Tab: searchFocused.toggle(); return true
        case kVK_DownArrow: moveSelection(1, extend: flags.contains(.shift)); return true
        case kVK_UpArrow: moveSelection(-1, extend: flags.contains(.shift)); return true
        case kVK_RightArrow where !searchFocused: moveSelection(1, extend: flags.contains(.shift)); return true
        case kVK_LeftArrow where !searchFocused: moveSelection(-1, extend: flags.contains(.shift)); return true
        case kVK_Space where !searchFocused: previewItem = selected; return true
        default:
            if !searchFocused, let text = event.characters, !text.isEmpty,
               text.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) && $0.value < 0xF700 }) {
                query += text; searchFocused = true; return true
            }
            return false
        }
    }
}

/// 面板快捷键在该窗口内处理，搜索输入仍保留系统编辑快捷键。
private struct PanelKeyboardMonitor: NSViewRepresentable {
    let onKeyDown: (NSEvent) -> Bool
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        context.coordinator.view = view
        context.coordinator.onKeyDown = onKeyDown
        context.coordinator.monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak owner = context.coordinator] event in
            guard let owner, let window = owner.view?.window, window.isKeyWindow, event.window === window,
                  window.attachedSheet == nil else { return event }
            return owner.onKeyDown?(event) == true ? nil : event
        }
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) { context.coordinator.onKeyDown = onKeyDown }
    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        if let monitor = coordinator.monitor { NSEvent.removeMonitor(monitor) }
    }
    @MainActor final class Coordinator {
        weak var view: NSView?
        var onKeyDown: ((NSEvent) -> Bool)?
        var monitor: Any?
    }
}

