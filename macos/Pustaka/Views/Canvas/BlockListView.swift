import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - Native AppKit Block Editor Field (Guaranteed Enter & Delete Support)

struct BlockEditorField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var font: NSFont
    var textColor: NSColor = .labelColor
    var isFocused: Bool
    var onCommit: () -> Void
    var onDeleteEmpty: () -> Void
    var onTextChanged: ((String) -> Void)? = nil

    func makeNSView(context: Context) -> NSTextField {
        let tf = NSTextField()
        tf.isBordered = false
        tf.drawsBackground = false
        tf.focusRingType = .none
        tf.font = font
        tf.textColor = textColor
        tf.placeholderString = placeholder
        tf.delegate = context.coordinator
        tf.cell?.wraps = true
        tf.cell?.isScrollable = false
        tf.maximumNumberOfLines = 0
        tf.lineBreakMode = .byWordWrapping
        tf.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return tf
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        nsView.font = font
        nsView.textColor = textColor
        nsView.placeholderString = placeholder

        if isFocused {
            DispatchQueue.main.async {
                if let window = nsView.window, window.firstResponder != nsView.currentEditor() {
                    window.makeFirstResponder(nsView)
                }
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: BlockEditorField

        init(_ parent: BlockEditorField) {
            self.parent = parent
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let tf = obj.object as? NSTextField else { return }
            parent.text = tf.stringValue
            parent.onTextChanged?(tf.stringValue)
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            // 1. Enter Key pressed -> Insert new block below and move focus
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                parent.onCommit()
                return true
            }

            // 2. Backspace / Delete Key pressed on empty text -> Delete block and move focus up
            if commandSelector == #selector(NSResponder.deleteBackward(_:)) {
                if textView.string.isEmpty {
                    parent.onDeleteEmpty()
                    return true
                }
            }

            return false
        }
    }
}

// MARK: - Block List View

struct BlockListView: View {
    @ObservedObject var store: WorkspaceStore
    let page: DocumentPage

    @State private var blocks: [UIBlockItem] = []
    @State private var hoveredBlockId: String? = nil
    @State private var draggedBlock: UIBlockItem? = nil
    @State private var focusedBlockId: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(Array(blocks.enumerated()), id: \.element.id) { index, block in
                BlockRowView(
                    block: block,
                    isHovered: hoveredBlockId == block.id,
                    isFirstBlock: index == 0,
                    isLastBlock: index == blocks.count - 1,
                    isFocused: focusedBlockId == block.id,
                    onFocus: {
                        focusedBlockId = block.id
                    },
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
                    onToggleExpand: {
                        if case .toggle(let isExpanded) = blocks[index].kind {
                            blocks[index].kind = .toggle(isExpanded: !isExpanded)
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
                        deleteBlockAt(index: index)
                    },
                    onDeleteEmpty: {
                        // If it's a list or quote, convert to normal paragraph first
                        switch block.kind {
                        case .bullet, .numbered, .quote, .todo, .toggle:
                            blocks[index].kind = .paragraph
                            syncBackToStore()
                        default:
                            deleteBlockAt(index: index)
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
                .frame(height: 140)
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

    private func deleteBlockAt(index: Int) {
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

// MARK: - Six Dots Notion-Style Handle (::)

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
        .foregroundStyle(.secondary.opacity(0.85))
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
    let isFocused: Bool
    let onFocus: () -> Void
    let onUpdateText: (String) -> Void
    let onToggleTodo: () -> Void
    let onToggleExpand: () -> Void
    let onInsertBelow: (UIBlockKind, String) -> Void
    let onTransformKind: (UIBlockKind) -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void
    let onDeleteEmpty: () -> Void

    @State private var textBuffer: String = ""
    @State private var isSlashCommandOpen: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .top, spacing: 4) {
                // Left Notion Gutter: [+] and [::] (width: 34pt)
                leftGutterControls
                    .padding(.top, topGutterPadding)

                // Main Block Content Body
                blockContentBody
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Inline Notion Slash Command Palette (Opens when typing "/")
            if isSlashCommandOpen {
                slashCommandPaletteView
                    .padding(.leading, 38)
                    .padding(.top, 4)
            }
        }
        .padding(.vertical, 2)
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

    // MARK: - Left Gutter Controls: [+] and [::]

    private var leftGutterControls: some View {
        HStack(spacing: 2) {
            // "+" Add Block Below Menu
            Menu {
                allBlocksInsertionMenu
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

            // "::" Drag Handle & Options Menu
            Menu {
                Menu("Turn into") {
                    allBlocksTransformMenu
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
        }
        .frame(width: 34)
        .opacity(isHovered ? 1.0 : 0.0)
        .animation(.easeInOut(duration: 0.12), value: isHovered)
    }

    // MARK: - Block Content Body

    @ViewBuilder
    private var blockContentBody: some View {
        switch block.kind {
        // 1. Headings
        case .heading(let level):
            BlockEditorField(
                text: $textBuffer,
                placeholder: "Heading \(level)...",
                font: NSFont.systemFont(ofSize: headingFontSize(level), weight: .bold),
                textColor: .labelColor,
                isFocused: isFocused,
                onCommit: {
                    onInsertBelow(.paragraph, "")
                },
                onDeleteEmpty: onDeleteEmpty,
                onTextChanged: checkSlashCommand
            )

        // 2. Plain Text Paragraph
        case .paragraph:
            BlockEditorField(
                text: $textBuffer,
                placeholder: "Type '/' for commands, or start writing...",
                font: NSFont.systemFont(ofSize: 15),
                textColor: .labelColor,
                isFocused: isFocused,
                onCommit: {
                    onInsertBelow(.paragraph, "")
                },
                onDeleteEmpty: onDeleteEmpty,
                onTextChanged: checkSlashCommand
            )

        // 3. Bulleted List
        case .bullet:
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("•")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 12)

                BlockEditorField(
                    text: $textBuffer,
                    placeholder: "List item...",
                    font: NSFont.systemFont(ofSize: 15),
                    textColor: .labelColor,
                    isFocused: isFocused,
                    onCommit: {
                        onInsertBelow(.bullet, "")
                    },
                    onDeleteEmpty: onDeleteEmpty,
                    onTextChanged: checkSlashCommand
                )
            }

        // 4. Numbered List
        case .numbered(let idx):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(idx).")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 18, alignment: .trailing)

                BlockEditorField(
                    text: $textBuffer,
                    placeholder: "List item...",
                    font: NSFont.systemFont(ofSize: 15),
                    textColor: .labelColor,
                    isFocused: isFocused,
                    onCommit: {
                        onInsertBelow(.numbered(index: idx + 1), "")
                    },
                    onDeleteEmpty: onDeleteEmpty,
                    onTextChanged: checkSlashCommand
                )
            }

        // 5. Toggle List
        case .toggle(let isExpanded):
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Button(action: onToggleExpand) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 16, height: 16)
                    }
                    .buttonStyle(.plain)

                    BlockEditorField(
                        text: $textBuffer,
                        placeholder: "Toggle list heading...",
                        font: NSFont.systemFont(ofSize: 15, weight: .semibold),
                        textColor: .labelColor,
                        isFocused: isFocused,
                        onCommit: {
                            onInsertBelow(.paragraph, "")
                        },
                        onDeleteEmpty: onDeleteEmpty,
                        onTextChanged: checkSlashCommand
                    )
                }

                if isExpanded {
                    Text("Empty toggle. Press '+' on left to add child blocks.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.leading, 24)
                        .padding(.vertical, 2)
                }
            }

        // 6. Quote Block
        case .quote:
            HStack(spacing: 12) {
                Rectangle()
                    .fill(Color.primary.opacity(0.35))
                    .frame(width: 3)
                    .clipShape(Capsule())

                BlockEditorField(
                    text: $textBuffer,
                    placeholder: "Quote...",
                    font: NSFont.systemFont(ofSize: 15),
                    textColor: .secondaryLabelColor,
                    isFocused: isFocused,
                    onCommit: {
                        onInsertBelow(.paragraph, "")
                    },
                    onDeleteEmpty: onDeleteEmpty,
                    onTextChanged: checkSlashCommand
                )
            }
            .padding(.vertical, 2)

        // 7. Divider Block
        case .divider:
            Divider()
                .frame(height: 1)
                .padding(.vertical, 8)

        // 8. To-do Checkbox
        case .todo(let checked):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Button(action: onToggleTodo) {
                    Image(systemName: checked ? "checkmark.square.fill" : "square")
                        .font(.system(size: 15))
                        .foregroundStyle(checked ? Color.accentColor : Color.secondary)
                }
                .buttonStyle(.plain)

                BlockEditorField(
                    text: $textBuffer,
                    placeholder: "To-do...",
                    font: NSFont.systemFont(ofSize: 15),
                    textColor: checked ? .secondaryLabelColor : .labelColor,
                    isFocused: isFocused,
                    onCommit: {
                        onInsertBelow(.todo(checked: false), "")
                    },
                    onDeleteEmpty: onDeleteEmpty,
                    onTextChanged: checkSlashCommand
                )
            }

        // 9. Callout Box
        case .callout(let icon, let theme):
            HStack(alignment: .top, spacing: 10) {
                Text(icon)
                    .font(.system(size: 18))

                BlockEditorField(
                    text: $textBuffer,
                    placeholder: "Callout note...",
                    font: NSFont.systemFont(ofSize: 15),
                    textColor: .labelColor,
                    isFocused: isFocused,
                    onCommit: {
                        onInsertBelow(.paragraph, "")
                    },
                    onDeleteEmpty: onDeleteEmpty,
                    onTextChanged: checkSlashCommand
                )
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.bg)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(theme.stroke.opacity(0.35), lineWidth: 1)
            )

        // 10. Web Bookmark / Link Card
        case .bookmark(let url):
            HStack(spacing: 10) {
                Image(systemName: "link.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.tint)

                VStack(alignment: .leading, spacing: 2) {
                    Text(textBuffer.isEmpty ? "Web Bookmark" : textBuffer)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)

                    Text(url)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                if let validUrl = URL(string: url) {
                    Button(action: {
                        NSWorkspace.shared.open(validUrl)
                    }) {
                        Image(systemName: "arrow.up.right.square")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )

        // 11. Code Block
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

        // 12. Grid / Columns
        case .grid(let columns):
            HStack(alignment: .top, spacing: 10) {
                ForEach(columns, id: \.self) { col in
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

    private func checkSlashCommand(_ text: String) {
        if text == "/" {
            isSlashCommandOpen = true
        } else if !text.hasPrefix("/") {
            isSlashCommandOpen = false
        }
        onUpdateText(text)
    }

    // MARK: - Notion Slash Command Palette View

    private var slashCommandPaletteView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 3) {
                Text("BASIC BLOCKS")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 8)
                    .padding(.top, 4)

                slashCommandItem(title: "Text", desc: "Start writing with plain text.", icon: "text.alignleft") {
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
                slashCommandItem(title: "To-do List", desc: "Track tasks with a checkbox.", icon: "checkmark.square") {
                    applySlashCommand(.todo(checked: false))
                }
                slashCommandItem(title: "Bulleted List", desc: "Create a simple bulleted list.", icon: "list.bullet") {
                    applySlashCommand(.bullet)
                }
                slashCommandItem(title: "Numbered List", desc: "Create a numbered list.", icon: "list.number") {
                    applySlashCommand(.numbered(index: 1))
                }
                slashCommandItem(title: "Toggle List", desc: "Collapsible toggle block.", icon: "arrowtriangle.right.fill") {
                    applySlashCommand(.toggle(isExpanded: false))
                }
                slashCommandItem(title: "Quote", desc: "Capture a quote with left bar.", icon: "text.quote") {
                    applySlashCommand(.quote)
                }
                slashCommandItem(title: "Divider", desc: "Visually divide blocks.", icon: "minus") {
                    applySlashCommand(.divider)
                }

                Divider().padding(.vertical, 2)

                Text("CALLOUTS & HIGHLIGHTS")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 8)

                slashCommandItem(title: "Info Callout", desc: "Highlighted note banner.", icon: "lightbulb.fill") {
                    applySlashCommand(.callout(icon: "💡", theme: .blue))
                }
                slashCommandItem(title: "Warning Callout", desc: "Highlighted warning banner.", icon: "exclamationmark.triangle.fill") {
                    applySlashCommand(.callout(icon: "⚠️", theme: .red))
                }
                slashCommandItem(title: "Tip Callout", desc: "Highlighted success tip banner.", icon: "checkmark.circle.fill") {
                    applySlashCommand(.callout(icon: "✅", theme: .green))
                }
                slashCommandItem(title: "Idea Callout", desc: "Highlighted goal note.", icon: "target") {
                    applySlashCommand(.callout(icon: "🎯", theme: .standard))
                }

                Divider().padding(.vertical, 2)

                Text("ADVANCED & MEDIA")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 8)

                slashCommandItem(title: "Code Block", desc: "Capture code snippet.", icon: "chevron.left.forwardslash.chevron.right") {
                    applySlashCommand(.code(lang: "rust"))
                }
                slashCommandItem(title: "Web Bookmark", desc: "Save a link as visual card.", icon: "link") {
                    applySlashCommand(.bookmark(url: "https://apple.com"))
                }
            }
            .padding(6)
        }
        .frame(width: 290, height: 320)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: Color.black.opacity(0.18), radius: 12, y: 5)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
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
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func applySlashCommand(_ kind: UIBlockKind) {
        self.textBuffer = ""
        self.isSlashCommandOpen = false
        onTransformKind(kind)
        onUpdateText("")
    }

    // MARK: - Reusable All Blocks Menus

    @ViewBuilder
    private var allBlocksInsertionMenu: some View {
        Section("Basic Blocks") {
            Button("Text") { onInsertBelow(.paragraph, "") }
            Button("Heading 1") { onInsertBelow(.heading(level: 1), "") }
            Button("Heading 2") { onInsertBelow(.heading(level: 2), "") }
            Button("Heading 3") { onInsertBelow(.heading(level: 3), "") }
            Button("To-do List") { onInsertBelow(.todo(checked: false), "") }
            Button("Bulleted List") { onInsertBelow(.bullet, "") }
            Button("Numbered List") { onInsertBelow(.numbered(index: 1), "") }
            Button("Toggle List") { onInsertBelow(.toggle(isExpanded: false), "") }
            Button("Quote") { onInsertBelow(.quote, "") }
            Button("Divider") { onInsertBelow(.divider, "") }
        }
        Section("Callouts") {
            Button("Info Callout (💡)") { onInsertBelow(.callout(icon: "💡", theme: .blue), "") }
            Button("Warning Callout (⚠️)") { onInsertBelow(.callout(icon: "⚠️", theme: .red), "") }
            Button("Tip Callout (✅)") { onInsertBelow(.callout(icon: "✅", theme: .green), "") }
            Button("Idea Callout (🎯)") { onInsertBelow(.callout(icon: "🎯", theme: .standard), "") }
        }
        Section("Advanced") {
            Button("Code Block") { onInsertBelow(.code(lang: "rust"), "") }
            Button("Web Bookmark") { onInsertBelow(.bookmark(url: "https://apple.com"), "Apple") }
        }
    }

    @ViewBuilder
    private var allBlocksTransformMenu: some View {
        Button("Text") { onTransformKind(.paragraph) }
        Button("Heading 1") { onTransformKind(.heading(level: 1)) }
        Button("Heading 2") { onTransformKind(.heading(level: 2)) }
        Button("Heading 3") { onTransformKind(.heading(level: 3)) }
        Button("To-do List") { onTransformKind(.todo(checked: false)) }
        Button("Bulleted List") { onTransformKind(.bullet) }
        Button("Numbered List") { onTransformKind(.numbered(index: 1)) }
        Button("Toggle List") { onTransformKind(.toggle(isExpanded: false)) }
        Button("Quote") { onTransformKind(.quote) }
        Button("Info Callout (💡)") { onTransformKind(.callout(icon: "💡", theme: .blue)) }
        Button("Warning Callout (⚠️)") { onTransformKind(.callout(icon: "⚠️", theme: .red)) }
        Button("Tip Callout (✅)") { onTransformKind(.callout(icon: "✅", theme: .green)) }
        Button("Code Block") { onTransformKind(.code(lang: "rust")) }
    }

    private var topGutterPadding: CGFloat {
        switch block.kind {
        case .heading(1): return 7
        case .heading(2): return 5
        case .heading(3): return 4
        case .callout: return 12
        case .code: return 12
        case .bookmark: return 14
        default: return 2
        }
    }

    private func headingFontSize(_ level: Int) -> CGFloat {
        switch level {
        case 1: return 26
        case 2: return 20
        default: return 16
        }
    }
}
