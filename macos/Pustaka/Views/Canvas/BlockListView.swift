import SwiftUI
import UniformTypeIdentifiers

struct BlockListView: View {
    @ObservedObject var store: WorkspaceStore
    let page: DocumentPage

    @State private var blocks: [UIBlockItem] = []
    @State private var hoveredBlockId: String? = nil
    @State private var draggedBlock: UIBlockItem? = nil
    @FocusState private var focusedBlockId: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(blocks.enumerated()), id: \.element.id) { index, block in
                BlockRowView(
                    block: block,
                    isHovered: hoveredBlockId == block.id,
                    isFirstBlock: index == 0,
                    isLastBlock: index == blocks.count - 1,
                    focusedBlockId: $focusedBlockId,
                    onUpdateText: { newText in
                        blocks[index].text = newText
                        syncBackToStore()
                    },
                    onToggleTodo: {
                        if case .todo(let checked) = blocks[index].kind {
                            blocks[index].kind = .todo(checked: !checked)
                            syncBackToStore()
                        }
                    },
                    onInsertBelow: { kind, initialText in
                        let newId = "blk_\(UUID().uuidString.prefix(6))"
                        let newBlock = UIBlockItem(
                            id: newId,
                            kind: kind,
                            text: initialText
                        )
                        blocks.insert(newBlock, at: index + 1)
                        hoveredBlockId = newId
                        syncBackToStore()
                        DispatchQueue.main.async {
                            self.focusedBlockId = newId
                        }
                    },
                    onTransformKind: { newKind in
                        blocks[index].kind = newKind
                        syncBackToStore()
                    },
                    onMoveUp: {
                        guard index > 0 else { return }
                        blocks.swapAt(index, index - 1)
                        syncBackToStore()
                    },
                    onMoveDown: {
                        guard index < blocks.count - 1 else { return }
                        blocks.swapAt(index, index + 1)
                        syncBackToStore()
                    },
                    onDuplicate: {
                        let newId = "blk_\(UUID().uuidString.prefix(6))"
                        let dup = UIBlockItem(
                            id: newId,
                            kind: block.kind,
                            text: block.text
                        )
                        blocks.insert(dup, at: index + 1)
                        syncBackToStore()
                        DispatchQueue.main.async {
                            self.focusedBlockId = newId
                        }
                    },
                    onDelete: {
                        if blocks.count > 1 {
                            let prevId = (index > 0) ? blocks[index - 1].id : nil
                            blocks.remove(at: index)
                            syncBackToStore()
                            if let prevId = prevId {
                                DispatchQueue.main.async {
                                    self.focusedBlockId = prevId
                                }
                            }
                        } else {
                            blocks[0] = UIBlockItem(id: "blk_1", kind: .paragraph, text: "")
                            syncBackToStore()
                        }
                    },
                    onDeleteEmpty: {
                        guard blocks.count > 1 else { return }
                        let prevId = (index > 0) ? blocks[index - 1].id : nil
                        blocks.remove(at: index)
                        syncBackToStore()
                        if let prevId = prevId {
                            DispatchQueue.main.async {
                                self.focusedBlockId = prevId
                            }
                        }
                    }
                )
                .onHover { isHovered in
                    if isHovered {
                        hoveredBlockId = block.id
                    } else if hoveredBlockId == block.id {
                        hoveredBlockId = nil
                    }
                }
                .onDrag {
                    self.draggedBlock = block
                    return NSItemProvider(object: block.id as NSString)
                }
                .onDrop(of: [UTType.text], delegate: BlockDropDelegate(
                    item: block,
                    blocks: $blocks,
                    draggedItem: $draggedBlock,
                    onComplete: { syncBackToStore() }
                ))
            }

            // Clickable bottom buffer to start writing at end
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: 120)
                .contentShape(Rectangle())
                .onTapGesture {
                    let newId = "blk_\(UUID().uuidString.prefix(6))"
                    if let last = blocks.last, !last.text.isEmpty {
                        let newBlock = UIBlockItem(
                            id: newId,
                            kind: .paragraph,
                            text: ""
                        )
                        blocks.append(newBlock)
                        syncBackToStore()
                        DispatchQueue.main.async {
                            self.focusedBlockId = newId
                        }
                    } else if let last = blocks.last {
                        self.focusedBlockId = last.id
                    }
                }
        }
        .onAppear {
            self.blocks = store.parseToUIBlocks(content: page.rawContent)
        }
        .onChange(of: page.id) { _, _ in
            self.blocks = store.parseToUIBlocks(content: page.rawContent)
        }
    }

    private func syncBackToStore() {
        let newPfs = store.uiBlocksToPfs(blocks: blocks)
        store.updatePageContent(newPfs)
    }
}

// MARK: - Drag & Drop Delegate for Reordering Blocks

struct BlockDropDelegate: DropDelegate {
    let item: UIBlockItem
    @Binding var blocks: [UIBlockItem]
    @Binding var draggedItem: UIBlockItem?
    let onComplete: () -> Void

    func dropEntered(info: DropInfo) {
        guard let draggedItem = self.draggedItem,
              draggedItem.id != item.id,
              let fromIndex = blocks.firstIndex(where: { $0.id == draggedItem.id }),
              let toIndex = blocks.firstIndex(where: { $0.id == item.id }) else { return }

        withAnimation(.easeInOut(duration: 0.18)) {
            blocks.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        self.draggedItem = nil
        onComplete()
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}

// MARK: - Six Dots Notion-Style Handle View

struct SixDotsHandleView: View {
    var body: some View {
        HStack(spacing: 2) {
            VStack(spacing: 2.5) {
                Circle().frame(width: 2.5, height: 2.5)
                Circle().frame(width: 2.5, height: 2.5)
                Circle().frame(width: 2.5, height: 2.5)
            }
            VStack(spacing: 2.5) {
                Circle().frame(width: 2.5, height: 2.5)
                Circle().frame(width: 2.5, height: 2.5)
                Circle().frame(width: 2.5, height: 2.5)
            }
        }
        .foregroundStyle(.secondary.opacity(0.8))
        .frame(width: 14, height: 16)
        .contentShape(Rectangle())
    }
}

// MARK: - Individual Block Row

struct BlockRowView: View {
    let block: UIBlockItem
    let isHovered: Bool
    let isFirstBlock: Bool
    let isLastBlock: Bool
    var focusedBlockId: FocusState<String?>.Binding
    let onUpdateText: (String) -> Void
    let onToggleTodo: () -> Void
    let onInsertBelow: (UIBlockKind, String) -> Void
    let onTransformKind: (UIBlockKind) -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void
    let onDeleteEmpty: () -> Void

    @State private var textBuffer: String = ""
    @State private var isSlashCommandOpen: Bool = false

    var isCodeBlock: Bool {
        if case .code = block.kind { return true }
        return false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .top, spacing: 4) {
                // Left Notion Gutter: [+] [⠿] [🗑]
                leftGutterControls
                    .padding(.top, topGutterPadding)

                // Main Block Content Body
                blockContentBody
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Inline Notion Slash Command Palette (Opens when typing "/")
            if isSlashCommandOpen {
                slashCommandPaletteView
                    .padding(.leading, 56)
                    .padding(.top, 4)
            }
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
        .onAppear {
            self.textBuffer = block.text
        }
        .onChange(of: block.text) { _, newVal in
            if self.textBuffer != newVal {
                self.textBuffer = newVal
            }
        }
    }

    // MARK: - Left Gutter Controls: [+] [⠿] [🗑]

    private var leftGutterControls: some View {
        HStack(spacing: 2) {
            // "+" Add Block Below Menu
            Menu {
                Button(action: { onInsertBelow(.paragraph, "") }) {
                    Label("Text", systemImage: "text.alignleft")
                }
                Button(action: { onInsertBelow(.heading(level: 1), "") }) {
                    Label("Heading 1", systemImage: "number")
                }
                Button(action: { onInsertBelow(.heading(level: 2), "") }) {
                    Label("Heading 2", systemImage: "number")
                }
                Button(action: { onInsertBelow(.heading(level: 3), "") }) {
                    Label("Heading 3", systemImage: "number")
                }
                Divider()
                Button(action: { onInsertBelow(.todo(checked: false), "") }) {
                    Label("To-do List", systemImage: "checkmark.square")
                }
                Button(action: { onInsertBelow(.callout(icon: "💡", theme: .blue), "") }) {
                    Label("Info Callout", systemImage: "lightbulb.fill")
                }
                Button(action: { onInsertBelow(.callout(icon: "⚠️", theme: .red), "") }) {
                    Label("Warning Callout", systemImage: "exclamationmark.triangle.fill")
                }
                Button(action: { onInsertBelow(.callout(icon: "✅", theme: .green), "") }) {
                    Label("Tip Callout", systemImage: "checkmark.circle.fill")
                }
                Button(action: { onInsertBelow(.code(lang: "rust"), "") }) {
                    Label("Code Block", systemImage: "chevron.left.forwardslash.chevron.right")
                }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 16, height: 16)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .help("Click to add block below")

            // "⠿" Drag Handle & Turn Into Menu
            Menu {
                Menu("Turn into") {
                    Button(action: { onTransformKind(.paragraph) }) {
                        Label("Text", systemImage: "text.alignleft")
                    }
                    Button(action: { onTransformKind(.heading(level: 1)) }) {
                        Label("Heading 1", systemImage: "number")
                    }
                    Button(action: { onTransformKind(.heading(level: 2)) }) {
                        Label("Heading 2", systemImage: "number")
                    }
                    Button(action: { onTransformKind(.heading(level: 3)) }) {
                        Label("Heading 3", systemImage: "number")
                    }
                    Divider()
                    Button(action: { onTransformKind(.todo(checked: false)) }) {
                        Label("To-do List", systemImage: "checkmark.square")
                    }
                    Button(action: { onTransformKind(.callout(icon: "💡", theme: .blue)) }) {
                        Label("Info Callout", systemImage: "lightbulb.fill")
                    }
                    Button(action: { onTransformKind(.callout(icon: "⚠️", theme: .red)) }) {
                        Label("Warning Callout", systemImage: "exclamationmark.triangle.fill")
                    }
                    Button(action: { onTransformKind(.callout(icon: "✅", theme: .green)) }) {
                        Label("Tip Callout", systemImage: "checkmark.circle.fill")
                    }
                    Button(action: { onTransformKind(.code(lang: "rust")) }) {
                        Label("Code Block", systemImage: "chevron.left.forwardslash.chevron.right")
                    }
                }

                Divider()

                Button(action: onMoveUp) {
                    Label("Move Up", systemImage: "arrow.up")
                }
                .disabled(isFirstBlock)

                Button(action: onMoveDown) {
                    Label("Move Down", systemImage: "arrow.down")
                }
                .disabled(isLastBlock)

                Button(action: onDuplicate) {
                    Label("Duplicate", systemImage: "plus.square.on.square")
                }

                Divider()

                Button(role: .destructive, action: onDelete) {
                    Label("Delete Block", systemImage: "trash")
                }
            } label: {
                SixDotsHandleView()
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .help("Drag to rearrange or click for block options")

            // Direct 1-Click Delete Button
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 10))
                    .foregroundStyle(.red.opacity(0.8))
                    .frame(width: 14, height: 16)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Delete block")
        }
        .frame(width: 52)
        .opacity(isHovered ? 1.0 : 0.0)
        .animation(.easeInOut(duration: 0.12), value: isHovered)
    }

    // MARK: - Block Content Body

    @ViewBuilder
    private var blockContentBody: some View {
        switch block.kind {
        case .heading(let level):
            TextField("Heading \(level)...", text: $textBuffer, axis: .vertical)
                .textFieldStyle(.plain)
                .font(headingFont(level))
                .fontWeight(.bold)
                .foregroundStyle(Color.primary)
                .focused(focusedBlockId, equals: block.id)
                .onKeyPress(.delete) {
                    if textBuffer.isEmpty {
                        onDeleteEmpty()
                        return .handled
                    }
                    return .ignored
                }
                .onChange(of: textBuffer) { _, newVal in
                    handleTextChange(newVal, nextKind: .paragraph)
                }

        case .paragraph:
            TextField("Type '/' for commands, or start writing...", text: $textBuffer, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .lineSpacing(4)
                .foregroundStyle(Color.primary)
                .focused(focusedBlockId, equals: block.id)
                .onKeyPress(.delete) {
                    if textBuffer.isEmpty {
                        onDeleteEmpty()
                        return .handled
                    }
                    return .ignored
                }
                .onChange(of: textBuffer) { _, newVal in
                    handleTextChange(newVal, nextKind: .paragraph)
                }

        case .callout(let icon, let theme):
            HStack(alignment: .top, spacing: 10) {
                Text(icon)
                    .font(.system(size: 18))

                TextField("Callout note...", text: $textBuffer, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15))
                    .foregroundStyle(Color.primary)
                    .focused(focusedBlockId, equals: block.id)
                    .onKeyPress(.delete) {
                        if textBuffer.isEmpty {
                            onDeleteEmpty()
                            return .handled
                        }
                        return .ignored
                    }
                    .onChange(of: textBuffer) { _, newVal in
                        handleTextChange(newVal, nextKind: .paragraph)
                    }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.bg)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(theme.stroke.opacity(0.35), lineWidth: 1)
            )

        case .todo(let checked):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Button(action: onToggleTodo) {
                    Image(systemName: checked ? "checkmark.square.fill" : "square")
                        .font(.system(size: 15))
                        .foregroundStyle(checked ? Color.accentColor : Color.secondary)
                }
                .buttonStyle(.plain)

                TextField("To-do...", text: $textBuffer, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15))
                    .strikethrough(checked, color: .secondary)
                    .foregroundStyle(checked ? Color.secondary : Color.primary)
                    .focused(focusedBlockId, equals: block.id)
                    .onKeyPress(.delete) {
                        if textBuffer.isEmpty {
                            onDeleteEmpty()
                            return .handled
                        }
                        return .ignored
                    }
                    .onChange(of: textBuffer) { _, newVal in
                        handleTextChange(newVal, nextKind: .todo(checked: false))
                    }
            }

        case .code(let lang):
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(lang.uppercased())
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Copy") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(textBuffer, forType: .string)
                    }
                    .buttonStyle(.borderless)
                    .font(.caption2)
                }

                TextEditor(text: $textBuffer)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 70)
                    .scrollContentBackground(.hidden)
                    .focused(focusedBlockId, equals: block.id)
                    .onChange(of: textBuffer) { _, newVal in
                        onUpdateText(newVal)
                    }
            }
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
            )

        case .grid(let columns):
            HStack(alignment: .top, spacing: 12) {
                ForEach(columns, id: \.self) { col in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(col)
                            .font(.subheadline)
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
        }
    }

    // MARK: - Auto-Add Block on Enter & Slash Command Detection

    private func handleTextChange(_ newVal: String, nextKind: UIBlockKind) {
        // 1. Check if user pressed Enter (newline inserted)
        if !isCodeBlock && newVal.contains("\n") {
            let parts = newVal.components(separatedBy: "\n")
            let firstPart = parts.first ?? ""
            let restPart = parts.dropFirst().joined(separator: "\n")

            self.textBuffer = firstPart
            self.isSlashCommandOpen = false
            onUpdateText(firstPart)
            onInsertBelow(nextKind, restPart)
            return
        }

        // 2. Check for Slash Command "/"
        if newVal == "/" {
            self.isSlashCommandOpen = true
        } else if !newVal.hasPrefix("/") {
            self.isSlashCommandOpen = false
        }

        onUpdateText(newVal)
    }

    // MARK: - Notion Slash Command Palette View

    private var slashCommandPaletteView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("BASIC BLOCKS")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 8)
                .padding(.top, 4)

            Group {
                slashCommandItem(title: "Text", desc: "Just start writing with plain text.", icon: "text.alignleft") {
                    applySlashCommand(.paragraph)
                }
                slashCommandItem(title: "Heading 1", desc: "Large section heading.", icon: "number") {
                    applySlashCommand(.heading(level: 1))
                }
                slashCommandItem(title: "Heading 2", desc: "Medium section heading.", icon: "number") {
                    applySlashCommand(.heading(level: 2))
                }
                slashCommandItem(title: "Heading 3", desc: "Small section heading.", icon: "number") {
                    applySlashCommand(.heading(level: 3))
                }
                slashCommandItem(title: "To-do List", desc: "Track tasks with a to-do list.", icon: "checkmark.square") {
                    applySlashCommand(.todo(checked: false))
                }
                slashCommandItem(title: "Info Callout", desc: "Highlighted note with icon.", icon: "lightbulb.fill") {
                    applySlashCommand(.callout(icon: "💡", theme: .blue))
                }
                slashCommandItem(title: "Warning Callout", desc: "Highlighted warning banner.", icon: "exclamationmark.triangle.fill") {
                    applySlashCommand(.callout(icon: "⚠️", theme: .red))
                }
                slashCommandItem(title: "Code Block", desc: "Capture a code snippet.", icon: "chevron.left.forwardslash.chevron.right") {
                    applySlashCommand(.code(lang: "rust"))
                }
            }
        }
        .padding(6)
        .frame(width: 270)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: Color.black.opacity(0.18), radius: 10, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }

    private func slashCommandItem(title: String, desc: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundStyle(.tint)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.primary)

                    Text(desc)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.primary.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }

    private func applySlashCommand(_ kind: UIBlockKind) {
        self.textBuffer = ""
        self.isSlashCommandOpen = false
        onTransformKind(kind)
        onUpdateText("")
    }

    private var topGutterPadding: CGFloat {
        switch block.kind {
        case .heading(1): return 7
        case .heading(2): return 5
        case .heading(3): return 4
        case .callout: return 10
        case .code: return 10
        default: return 2
        }
    }

    private func headingFont(_ level: Int) -> Font {
        switch level {
        case 1: return .system(size: 24, weight: .bold)
        case 2: return .system(size: 19, weight: .bold)
        default: return .system(size: 16, weight: .bold)
        }
    }
}
