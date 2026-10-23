import AppKit
import SwiftUI
import UniformTypeIdentifiers
import XPastepalCore

struct LibraryView: View {
    let store: ClipboardStore
    let onShowQuickPanel: () -> Void
    let onShowSettings: () -> Void

    @State private var selection = "all"
    @State private var query = ""
    @State private var sourceFilter = ""
    @State private var selectedIDs: Set<UUID> = []
    @State private var focusedItemID: UUID?
    @State private var selectionAnchor: UUID?
    @State private var sheet: LibrarySheet?
    @State private var showsClearConfirmation = false
    @State private var isWorking = false
    @State private var gridColumnCount = 2
    @AppStorage("libraryLayout") private var layout = "grid"
    @AppStorage("libraryShowsDetails") private var showsDetails = true
    @FocusState private var searchIsFocused: Bool

    private var selectedCollectionID: UUID? {
        selection.hasPrefix("collection:") ? UUID(uuidString: String(selection.dropFirst(11))) : nil
    }

    private var visibleItems: [ClipItem] {
        store.filteredItems(query: query, kind: nil, collectionID: selectedCollectionID, pinnedOnly: selection == "pinned")
            .filter { item in
                let matchesKind: Bool
                switch selection {
                case "text": matchesKind = item.kind == .text
                case "link": matchesKind = item.kind == .link
                case "image": matchesKind = item.kind == .image
                case "file": matchesKind = item.kind == .file
                default: matchesKind = true
                }
                return matchesKind && (sourceFilter.isEmpty || item.sourceApp == sourceFilter)
            }
    }

    private var selectedItem: ClipItem? {
        guard selectedIDs.count == 1 else { return nil }
        return visibleItems.first { selectedIDs.contains($0.id) }
    }

    private var selectedItems: [ClipItem] { visibleItems.filter { selectedIDs.contains($0.id) } }

    private var sectionTitle: String {
        switch selection {
        case "pinned": return "已收藏"
        case "text": return "文字"
        case "link": return "链接"
        case "image": return "图片"
        case "file": return "文件"
        default: return store.collections.first { $0.id == selectedCollectionID }?.name ?? "全部历史"
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: 196)
            Divider()
            mainContent
                .frame(minWidth: 500, maxWidth: .infinity, maxHeight: .infinity)
            if showsDetails {
                Divider()
                detailColumn.frame(width: 286)
            }
        }
        .frame(minWidth: 1000, minHeight: 620)
        .background(Color(nsColor: .windowBackgroundColor))
        .tint(Color(red: 0.32, green: 0.40, blue: 0.90))
        .sheet(item: $sheet) { destination in
            switch destination {
            case .collection(let collection):
                LibraryCollectionSheet(store: store, collection: collection)
            case .preview(let item):
                LibraryPreviewSheet(item: item, store: store)
            case .newText:
                LibraryTextSheet(store: store, initialText: "", title: "新增文本")
            case .recognizedText(let text):
                LibraryTextSheet(store: store, initialText: text, title: "图片识别结果")
            }
        }
        .confirmationDialog("清空未收藏的历史？", isPresented: $showsClearConfirmation, titleVisibility: .visible) {
            Button("清空未收藏", role: .destructive) { store.clearUnpinned() }
            Button("取消", role: .cancel) { }
        } message: {
            Text("已收藏的内容会保留，其余历史将从 XPastepal 中删除。")
        }
        .onChange(of: visibleItems.map(\.id)) { oldIDs, ids in
            selectedIDs.formIntersection(ids)
            if let focusedItemID, !ids.contains(focusedItemID) {
                let oldIndex = oldIDs.firstIndex(of: focusedItemID) ?? 0
                self.focusedItemID = ids.isEmpty ? nil : ids[min(oldIndex, ids.count - 1)]
                if let next = self.focusedItemID { selectedIDs = [next] }
            }
        }
        .background(LibraryKeyboardMonitor(onKeyDown: handleKeyDown))
        .background {
            Button("搜索") { searchIsFocused = true }
                .keyboardShortcut("f", modifiers: .command)
                .hidden()
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "square.on.square.fill")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 39, height: 39)
                    .background(LinearGradient(colors: [.indigo, .blue], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 3) {
                    Text("XPastepal")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                    Text("随手复制，有序收纳")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)
            .padding(.bottom, 27)

            ScrollView {
                VStack(alignment: .leading, spacing: 5) {
                    sectionLabel("资料库")
                    navigationRow("全部历史", symbol: "square.grid.2x2", key: "all", count: store.items.count)
                    navigationRow("已收藏", symbol: "heart", key: "pinned", count: store.items.filter(\.isPinned).count)
                    sectionLabel("内容类型")
                        .padding(.top, 19)
                    navigationRow("文字", symbol: "text.alignleft", key: "text")
                    navigationRow("链接", symbol: "link", key: "link")
                    navigationRow("图片", symbol: "photo", key: "image")
                    navigationRow("文件", symbol: "doc", key: "file")
                    HStack {
                        sectionLabel("我的集合")
                        Spacer()
                        Button { sheet = .collection(nil) } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .help("新建集合")
                        .padding(.trailing, 12)
                    }
                    .padding(.top, 19)
                    ForEach(store.collections) { collection in
                        navigationRow(collection.name, symbol: "folder", key: "collection:\(collection.id.uuidString)")
                            .contextMenu {
                                Button("重命名", systemImage: "pencil") { sheet = .collection(collection) }
                                Divider()
                                Button("删除集合", role: .destructive) {
                                    store.deleteCollection(collection)
                                    if selectedCollectionID == collection.id { selection = "all" }
                                }
                            }
                    }
                    if store.collections.isEmpty {
                        Text("用集合整理常用片段")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 12)
                            .padding(.top, 4)
                    }
                    sectionLabel("来源应用")
                        .padding(.top, 19)
                    Button { sourceFilter = "" } label: {
                        Label("所有应用", systemImage: "square.stack.3d.up")
                            .font(.system(size: 12))
                            .foregroundStyle(sourceFilter.isEmpty ? Color.accentColor : .secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    ForEach(Array(Set(store.items.map(\.sourceApp))).sorted(), id: \.self) { app in
                        Button { sourceFilter = app } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "app").frame(width: 17)
                                Text(app).lineLimit(1)
                                Spacer(minLength: 0)
                            }
                            .font(.system(size: 12))
                            .foregroundStyle(sourceFilter == app ? Color.accentColor : .primary.opacity(0.75))
                            .padding(.horizontal, 12).frame(height: 31)
                            .background(sourceFilter == app ? Color.accentColor.opacity(0.10) : .clear, in: RoundedRectangle(cornerRadius: 8))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
            }

            VStack(spacing: 8) {
                Button {
                    if store.isMonitoring { store.stopMonitoring() } else { store.startMonitoring() }
                } label: {
                    HStack(spacing: 8) {
                        Circle().fill(store.isMonitoring ? Color.green : Color.orange)
                            .frame(width: 6, height: 6)
                        Text(store.isMonitoring ? "正在记录剪贴板" : "记录已暂停")
                            .font(.system(size: 11))
                        Spacer(minLength: 0)
                        Image(systemName: store.isMonitoring ? "pause" : "play")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .padding(10)
                    .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .help(store.isMonitoring ? "暂停记录新内容" : "恢复记录新内容")
                HStack {
                    Button(action: onShowSettings) {
                        Label("设置", systemImage: "gearshape")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(",", modifiers: .command)
                    .foregroundStyle(.secondary)
                    Spacer()
                    Text("本地保存")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 3)
            }
            .padding(14)
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.36))
    }

    private var mainContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(sectionTitle)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                    Text("\(visibleItems.count) 条内容\(sourceFilter.isEmpty ? "" : " · \(sourceFilter)")")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Button(action: onShowQuickPanel) {
                    Image(systemName: "rectangle.bottomthird.inset.filled")
                        .font(.system(size: 15))
                        .frame(width: 33, height: 33)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 9))
                .help("打开快捷面板")
                Button { showsDetails.toggle() } label: {
                    Image(systemName: "sidebar.right")
                        .font(.system(size: 15))
                        .frame(width: 28, height: 32)
                }
                .buttonStyle(.plain)
                .foregroundStyle(showsDetails ? Color.accentColor : .secondary)
                .help(showsDetails ? "隐藏详情" : "显示详情")
                Menu {
                    Button("新增文本", systemImage: "square.and.pencil") { sheet = .newText }
                    Button("新建集合", systemImage: "folder.badge.plus") { sheet = .collection(nil) }
                    Divider()
                    Button("导入历史…", systemImage: "square.and.arrow.down") { importHistory() }
                    Button("导出全部历史…", systemImage: "square.and.arrow.up") { exportHistory() }
                    Divider()
                    Button("全选", systemImage: "checkmark.circle") { selectAll() }
                    Divider()
                    Button("清空未收藏的历史", systemImage: "trash", role: .destructive) { showsClearConfirmation = true }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 15, weight: .medium))
                        .frame(width: 28, height: 32)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .help("更多操作")
                .disabled(isWorking)
            }
            .padding(.horizontal, 24)
            .padding(.top, 26)
            .padding(.bottom, 21)

            searchBar
                .padding(.horizontal, 24)
                .padding(.bottom, 20)

            if !selectedIDs.isEmpty { selectionToolbar }

            if let error = store.errorMessage, !error.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text(error).textSelection(.enabled)
                    Spacer(minLength: 0)
                    Button { store.errorMessage = nil } label: { Image(systemName: "xmark") }
                        .buttonStyle(.plain)
                        .help("关闭提示")
                }
                .font(.system(size: 11))
                .foregroundStyle(.orange)
                .padding(11)
                .background(Color.orange.opacity(0.09), in: RoundedRectangle(cornerRadius: 9))
                .padding(.horizontal, 24)
                .padding(.bottom, 15)
            }

            if visibleItems.isEmpty {
                emptyState
            } else {
                itemsContent
            }

            footer
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            TextField("搜索内容、应用…", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .focused($searchIsFocused)
                .onSubmit {
                    if let first = visibleItems.first {
                        select(first, modifiers: [])
                    }
                }
            if !query.isEmpty {
                Button { query = "" } label: { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.plain)
                    .foregroundStyle(.tertiary)
                    .help("清除搜索")
            } else {
                Text("⌘ F")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
            Divider().frame(height: 16)
            Menu {
                Button("所有应用") { sourceFilter = "" }
                Divider()
                ForEach(Array(Set(store.items.map(\.sourceApp))).sorted(), id: \.self) { app in
                    Button(app) { sourceFilter = app }
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "line.3.horizontal.decrease")
                    Text(sourceFilter.isEmpty ? "所有应用" : sourceFilter)
                        .lineLimit(1)
                }
                .font(.system(size: 11))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("按来源应用筛选")
            Divider().frame(height: 16)
            Picker("显示方式", selection: $layout) {
                Image(systemName: "square.grid.2x2").tag("grid")
                    .help("卡片视图")
                Image(systemName: "list.bullet").tag("list")
                    .help("列表视图")
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 65)
        }
        .padding(.horizontal, 13)
        .frame(height: 40)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.primary.opacity(0.07)))
    }

    private var itemsContent: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView {
                    if layout == "list" {
                        LazyVStack(spacing: 5) {
                            ForEach(visibleItems) { item in
                                LibraryListRow(item: item, isSelected: selectedIDs.contains(item.id),
                                    onSelect: { select(item, modifiers: NSEvent.modifierFlags) },
                                    onCopy: { store.copy(item) })
                                    .id(item.id)
                                    .contextMenu { itemMenu(item) }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)
                    } else {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: columns(for: geometry.size.width)), spacing: 14) {
                            ForEach(visibleItems) { item in
                                ClipCard(item: item, isSelected: selectedIDs.contains(item.id),
                                    onSelect: { select(item, modifiers: NSEvent.modifierFlags) },
                                    onCopy: { store.copy(item) })
                                    .id(item.id)
                                    .contextMenu { itemMenu(item) }
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 22)
                    }
                }
                .onChange(of: focusedItemID) { _, id in
                    guard let id else { return }
                    withAnimation(.easeOut(duration: 0.12)) { proxy.scrollTo(id) }
                }
                .onAppear { gridColumnCount = columns(for: geometry.size.width) }
                .onChange(of: geometry.size.width) { _, width in gridColumnCount = columns(for: width) }
            }
        }
    }

    private func columns(for width: CGFloat) -> Int { max(1, Int((width - 34) / 219)) }

    private var selectionToolbar: some View {
        HStack(spacing: 12) {
            Text("已选择 \(selectedIDs.count) 项").foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Button { copySelection() } label: { Image(systemName: "doc.on.doc") }
                .help("复制所选（⌘C / 回车）")
            Menu {
                if selectedItems.contains(where: { $0.collectionID != nil }) {
                    Button("从集合移除") { store.move(ids: selectedIDs, to: nil) }
                }
                ForEach(store.collections) { collection in
                    Button(collection.name) { store.move(ids: selectedIDs, to: collection.id) }
                }
            } label: { Image(systemName: "folder.badge.plus") }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("将所选移到集合")
            Button { toggleSelectedPin() } label: {
                FavoriteIcon(isFavorite: !selectedItems.isEmpty && selectedItems.allSatisfy(\.isPinned))
            }
                .help("收藏 / 取消收藏所选")
            Button { deleteSelection() } label: { Image(systemName: "trash") }
                .help("删除所选（⌘⌫）")
            Button { selectedIDs.removeAll(); focusedItemID = nil } label: { Image(systemName: "xmark") }
                .help("取消选择")
        }
        .buttonStyle(.plain)
        .font(.system(size: 11))
        .padding(.horizontal, 13)
        .padding(.vertical, 9)
        .background(Color.accentColor.opacity(0.065), in: RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
    }

    @ViewBuilder private func itemMenu(_ item: ClipItem) -> some View {
        Button("复制", systemImage: "doc.on.doc") { copy(menuItems(for: item)) }
        Button("复制纯文本", systemImage: "text.alignleft") { store.copy(item, plainText: true) }
            .disabled(item.text.isEmpty)
        Button("预览", systemImage: "eye") { sheet = .preview(item) }
        if item.kind == .link, let url = URL(string: item.text.trimmingCharacters(in: .whitespacesAndNewlines)) {
            Button("在浏览器中打开", systemImage: "safari") { NSWorkspace.shared.open(url) }
        }
        if item.kind == .file {
            Button("在 Finder 中显示", systemImage: "folder") {
                NSWorkspace.shared.activateFileViewerSelecting(item.filePaths.map { URL(fileURLWithPath: $0) })
            }
        }
        if item.kind == .image {
            Button("识别图片中的文字", systemImage: "text.viewfinder") { recognizeText(item) }
                .disabled(isWorking)
        }
        if item.kind == .text || item.kind == .link {
            Menu("文本转换") {
                ForEach(TextTransformation.allCases) { transformation in
                    Button(transformation.title) { transform(item, using: transformation) }
                }
            }
        }
        Divider()
        Button {
            for target in menuItems(for: item) where target.isPinned == item.isPinned { store.togglePin(target) }
        } label: {
            Label { Text(item.isPinned ? "取消收藏" : "收藏") } icon: { FavoriteIcon(isFavorite: item.isPinned) }
        }
        Menu("移到集合") {
            if menuItems(for: item).contains(where: { $0.collectionID != nil }) {
                Button("从集合移除") { store.move(ids: Set(menuItems(for: item).map(\.id)), to: nil) }
            }
            ForEach(store.collections) { collection in
                Button(collection.name) { store.move(ids: Set(menuItems(for: item).map(\.id)), to: collection.id) }
            }
        }
        Divider()
        Button("删除", systemImage: "trash", role: .destructive) { store.delete(ids: Set(menuItems(for: item).map(\.id))) }
    }

    private func menuItems(for item: ClipItem) -> [ClipItem] {
        selectedIDs.contains(item.id) ? selectedItems : [item]
    }

    private func select(_ item: ClipItem, modifiers: NSEvent.ModifierFlags) {
        searchIsFocused = false
        NSApp.keyWindow?.makeFirstResponder(nil)
        if modifiers.contains(.shift), let anchor = selectionAnchor,
           let start = visibleItems.firstIndex(where: { $0.id == anchor }),
           let end = visibleItems.firstIndex(where: { $0.id == item.id }) {
            let range = Set(visibleItems[min(start, end)...max(start, end)].map(\.id))
            selectedIDs = modifiers.contains(.command) ? selectedIDs.union(range) : range
        } else if modifiers.contains(.command) {
            if selectedIDs.contains(item.id) { selectedIDs.remove(item.id) } else { selectedIDs.insert(item.id) }
            selectionAnchor = item.id
        } else {
            selectedIDs = [item.id]
            selectionAnchor = item.id
        }
        focusedItemID = item.id
    }

    private func selectAll() {
        selectedIDs = Set(visibleItems.map(\.id))
        focusedItemID = focusedItemID ?? visibleItems.first?.id
    }

    private func copySelection() { copy(selectedItems) }

    private func copy(_ items: [ClipItem]) {
        if items.count == 1, let item = items.first { store.copy(item) }
        else if items.count > 1 { store.copyItems(items) }
    }

    private func transform(_ item: ClipItem, using transformation: TextTransformation) {
        if let result = store.transform(item, using: transformation) { sheet = .preview(result) }
    }

    private func deleteSelection() { store.delete(ids: selectedIDs) }

    private func toggleSelectedPin() {
        let targets = selectedItems
        let shouldPin = targets.contains { !$0.isPinned }
        for item in targets where item.isPinned != shouldPin { store.togglePin(item) }
    }

    private func handleKeyDown(_ event: NSEvent) -> Bool {
        guard sheet == nil, !showsClearConfirmation else { return false }
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if modifiers.contains(.command), !modifiers.contains(.option), !modifiers.contains(.control) {
            switch event.charactersIgnoringModifiers?.lowercased() {
            case "a": selectAll(); return true
            case "c": copySelection(); return !selectedIDs.isEmpty
            case "i": showsDetails.toggle(); return true
            default: break
            }
            if event.keyCode == 51 { deleteSelection(); return true }
        }
        guard !modifiers.contains(.command), !modifiers.contains(.option), !modifiers.contains(.control) else { return false }
        switch event.keyCode {
        case 123: moveSelection(by: -1, extending: modifiers.contains(.shift))
        case 124: moveSelection(by: 1, extending: modifiers.contains(.shift))
        case 125: moveSelection(by: layout == "list" ? 1 : gridColumnCount, extending: modifiers.contains(.shift))
        case 126: moveSelection(by: layout == "list" ? -1 : -gridColumnCount, extending: modifiers.contains(.shift))
        case 36, 76:
            if modifiers.contains(.shift), let item = selectedItem { store.copy(item, plainText: true) }
            else { copySelection() }
        case 49:
            guard let item = selectedItem else { return false }
            sheet = .preview(item)
        case 53:
            selectedIDs.removeAll()
            focusedItemID = nil
        default: return false
        }
        return true
    }

    private func moveSelection(by offset: Int, extending: Bool) {
        guard !visibleItems.isEmpty else { return }
        let index = focusedItemID.flatMap { id in visibleItems.firstIndex { $0.id == id } }
        let target = index.map { min(max(0, $0 + offset), visibleItems.count - 1) } ?? 0
        select(visibleItems[target], modifiers: extending ? .shift : [])
    }

    private func recognizeText(_ item: ClipItem) {
        isWorking = true
        Task { @MainActor in
            defer { isWorking = false }
            if let text = await store.recognizeText(in: item) { sheet = .recognizedText(text) }
        }
    }

    private func importHistory() {
        let panel = NSOpenPanel()
        panel.title = "导入 XPastepal 历史"
        panel.message = "选择 XPastepal 导出的 JSON 文件，导入内容会与现有历史合并。"
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        isWorking = true
        Task { @MainActor in
            defer { isWorking = false }
            do { try await store.importHistory(from: url) }
            catch { store.errorMessage = "导入失败：\(error.localizedDescription)" }
        }
    }

    private func exportHistory() {
        let panel = NSSavePanel()
        panel.title = "导出 XPastepal 历史"
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "XPastepal-\(Date().formatted(.iso8601.year().month().day().dateSeparator(.dash))).json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        isWorking = true
        Task { @MainActor in
            defer { isWorking = false }
            do { try await store.exportHistory(to: url) }
            catch { store.errorMessage = "导出失败：\(error.localizedDescription)" }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 13) {
            Image(systemName: query.isEmpty && sourceFilter.isEmpty ? "square.on.square" : "magnifyingglass")
                .font(.system(size: 37, weight: .ultraLight))
                .foregroundStyle(.secondary)
                .frame(width: 86, height: 86)
                .background(Color.accentColor.opacity(0.065), in: RoundedRectangle(cornerRadius: 25))
            Text(emptyTitle)
                .font(.system(size: 16, weight: .semibold))
            Text(emptyMessage)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(5)
            if !query.isEmpty || !sourceFilter.isEmpty {
                Button("清除筛选") { query = ""; sourceFilter = "" }
                    .buttonStyle(.bordered)
            } else if !store.isMonitoring {
                Button("恢复记录") { store.startMonitoring() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 45)
    }

    private var emptyTitle: String {
        if !query.isEmpty || !sourceFilter.isEmpty { return "没有找到匹配内容" }
        if selection == "pinned" { return "常用内容，随时留住" }
        if selectedCollectionID != nil { return "集合还是空的" }
        return selection == "all" ? "从一次复制开始" : "还没有\(sectionTitle)记录"
    }

    private var emptyMessage: String {
        if !query.isEmpty || !sourceFilter.isEmpty { return "试试其他关键词，或清除应用筛选。" }
        if selection == "pinned" { return "在内容卡片上右键选择「收藏」，\n就能在这里快速找到它。" }
        if selectedCollectionID != nil { return "从全部历史中选一条内容，\n在详情里将它移入这个集合。" }
        if selection != "all" { return "复制\(sectionTitle)后，会自动记录到这里。" }
        return "复制文字、链接、图片或文件，\n内容会自动出现在这里。"
    }

    private var footer: some View {
        HStack(spacing: 5) {
            if isWorking { ProgressView().controlSize(.mini) }
            Text("↵ 复制 · 空格预览 · ⌘/⇧ 多选")
            Spacer()
            Text(store.lastAction ?? "只保存在这台 Mac 上")
                .lineLimit(1)
        }
        .font(.system(size: 10))
        .foregroundStyle(.tertiary)
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }

    @ViewBuilder private var detailColumn: some View {
        if let item = selectedItem {
            LibraryClipDetailView(item: item, store: store, isWorking: isWorking,
                onRecognize: { recognizeText(item) }, onPreview: { sheet = .preview(item) },
                onTransform: { transform(item, using: $0) })
                .id(item.id)
        } else if selectedIDs.count > 1 {
            VStack(spacing: 16) {
                Image(systemName: "square.stack.3d.up")
                    .font(.system(size: 34, weight: .light))
                    .foregroundStyle(.secondary)
                Text("已选择 \(selectedIDs.count) 项").font(.headline)
                Text("复制、收藏或将内容移到同一集合。")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Button("复制所选", action: copySelection).buttonStyle(.borderedProminent)
                Button("取消选择") { selectedIDs.removeAll(); focusedItemID = nil }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.25))
        } else {
            VStack(spacing: 12) {
                HStack {
                    Text("内容详情")
                        .font(.system(size: 12, weight: .semibold))
                    Spacer()
                    Image(systemName: "sidebar.right")
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 20)
                .padding(.top, 29)
                Spacer()
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 30, weight: .ultraLight))
                    .foregroundStyle(.tertiary)
                Text("选择一条内容")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                Text("查看预览、编辑和整理")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                Spacer()
                Spacer().frame(height: 30)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.25))
        }
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 12)
            .padding(.bottom, 5)
    }

    private func navigationRow(_ title: String, symbol: String, key: String, count: Int? = nil) -> some View {
        Button {
            selection = key
            selectedIDs.removeAll()
            focusedItemID = nil
            selectionAnchor = nil
        } label: {
            HStack(spacing: 10) {
                Group {
                    if key == "pinned" {
                        FavoriteIcon(isFavorite: selection == key)
                    } else {
                        Image(systemName: symbol)
                    }
                }
                .font(.system(size: 13, weight: selection == key ? .semibold : .regular))
                .frame(width: 17)
                Text(title)
                    .font(.system(size: 12, weight: selection == key ? .semibold : .regular))
                    .lineLimit(1)
                Spacer(minLength: 0)
                if let count {
                    Text(count.formatted())
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(selection == key ? Color.accentColor : .secondary)
                }
            }
            .foregroundStyle(selection == key ? Color.accentColor : .primary.opacity(0.75))
            .padding(.horizontal, 12)
            .frame(height: 35)
            .background(selection == key ? Color.accentColor.opacity(0.10) : .clear, in: RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(title)
    }
}

