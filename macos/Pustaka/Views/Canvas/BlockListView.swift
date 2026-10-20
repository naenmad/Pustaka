import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - Native AppKit Block Editor Field (Guaranteed Enter, Delete & Slash Command Support)

struct BlockEditorField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var font: NSFont
    var textColor: NSColor = .labelColor
    var isFocused: Bool
    var onCommit: () -> Void
    var onDeleteEmpty: () -> Void
    var onSlashCommit: (() -> Bool)? = nil
    var onEscape: (() -> Bool)? = nil
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
            // 1. Enter Key pressed
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                if let slashHandler = parent.onSlashCommit, slashHandler() {
                    return true
                }
                parent.onCommit()
                return true
            }

            // 2. Escape Key pressed
            if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                if let escHandler = parent.onEscape, escHandler() {
                    return true
                }
            }

            // 3. Backspace / Delete Key pressed on empty text
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

// MARK: - Slash Command Palette Item Model

struct SlashCommandItem: Identifiable {
    let id: String
    let title: String
    let desc: String
    let icon: String
    let keywords: [String]
    let kind: UIBlockKind
}

let allSlashCommands: [SlashCommandItem] = [
    // 1. Basic Blocks
    SlashCommandItem(id: "text", title: "Text", desc: "Start writing with plain text.", icon: "text.alignleft", keywords: ["text", "p", "paragraph", "plain"], kind: .paragraph),
    SlashCommandItem(id: "h1", title: "Heading 1", desc: "Large section heading.", icon: "number", keywords: ["h1", "heading 1", "header 1", "#", "title"], kind: .heading(level: 1)),
    SlashCommandItem(id: "h2", title: "Heading 2", desc: "Medium section heading.", icon: "number", keywords: ["h2", "heading 2", "header 2", "##", "subtitle"], kind: .heading(level: 2)),
    SlashCommandItem(id: "h3", title: "Heading 3", desc: "Small section heading.", icon: "number", keywords: ["h3", "heading 3", "header 3", "###", "subheading"], kind: .heading(level: 3)),
    SlashCommandItem(id: "todo", title: "To-do List", desc: "Track tasks with a to-do checkbox.", icon: "checkmark.square", keywords: ["todo", "task", "check", "checkbox", "done", "[]"], kind: .todo(checked: false)),
    SlashCommandItem(id: "bullet", title: "Bulleted List", desc: "Create a simple bulleted list.", icon: "list.bullet", keywords: ["bullet", "bulleted", "list", "ul", "-", "*"], kind: .bullet),
    SlashCommandItem(id: "numbered", title: "Numbered List", desc: "Create an ordered numbered list.", icon: "list.number", keywords: ["number", "numbered", "list", "ol", "1.", "ordered"], kind: .numbered(index: 1)),
    SlashCommandItem(id: "toggle", title: "Toggle List", desc: "Collapsible toggle block to hide content.", icon: "arrowtriangle.right.fill", keywords: ["toggle", "collapse", "dropdown", "expand", ">"], kind: .toggle(isExpanded: false)),
    SlashCommandItem(id: "quote", title: "Quote", desc: "Capture a quote with an accent bar.", icon: "text.quote", keywords: ["quote", "blockquote", "citation", ">"], kind: .quote),
    SlashCommandItem(id: "divider", title: "Divider", desc: "Visually divide blocks with a clean line.", icon: "minus", keywords: ["divider", "line", "separator", "hr", "---", "rule"], kind: .divider),

    // 2. Callouts
    SlashCommandItem(id: "callout_info", title: "Info Callout", desc: "Highlighted blue information note.", icon: "lightbulb.fill", keywords: ["info", "callout", "note", "tip", "blue", "lightbulb"], kind: .callout(icon: "💡", theme: .blue)),
    SlashCommandItem(id: "callout_warn", title: "Warning Callout", desc: "Highlighted warning alert banner.", icon: "exclamationmark.triangle.fill", keywords: ["warn", "warning", "alert", "danger", "red"], kind: .callout(icon: "⚠️", theme: .red)),
    SlashCommandItem(id: "callout_tip", title: "Tip Callout", desc: "Highlighted success or tip banner.", icon: "checkmark.circle.fill", keywords: ["tip", "success", "green", "check"], kind: .callout(icon: "✅", theme: .green)),
    SlashCommandItem(id: "callout_idea", title: "Idea Callout", desc: "Highlighted idea / goal note.", icon: "target", keywords: ["idea", "target", "goal", "callout"], kind: .callout(icon: "🎯", theme: .standard)),

    // 3. Media & Advanced
    SlashCommandItem(id: "code", title: "Code Block", desc: "Code snippet with syntax support.", icon: "curlybraces", keywords: ["code", "snippet", "pre", "syntax", "rust", "python", "js", "swift"], kind: .code(lang: "rust")),
    SlashCommandItem(id: "bookmark", title: "Web Bookmark", desc: "Save a web link as a visual preview card.", icon: "link", keywords: ["bookmark", "link", "url", "web", "card", "http"], kind: .bookmark(url: "https://")),
    SlashCommandItem(id: "image", title: "Image", desc: "Insert an image with caption.", icon: "photo", keywords: ["image", "img", "photo", "picture", "figure"], kind: .image(url: "", caption: "")),
    SlashCommandItem(id: "math", title: "Math / Equation", desc: "TeX or Typst mathematical formula.", icon: "function", keywords: ["math", "equation", "formula", "latex", "tex"], kind: .math(expression: "")),
    SlashCommandItem(id: "table", title: "Table / Grid", desc: "Simple table or multi-column grid.", icon: "tablecells", keywords: ["table", "grid", "column", "columns"], kind: .grid(columns: ["Column 1", "Column 2", "Column 3"]))
]

// MARK: - Block List View

struct BlockListView: View {
    @ObservedObject var store: WorkspaceStore
    let page: DocumentPage
    @Binding var focusedBlockId: String?

    @State private var blocks: [UIBlockItem] = []
    @State private var hoveredBlockId: String? = nil
    @State private var draggedBlock: UIBlockItem? = nil

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
                    },
                    onStartDrag: {
                        self.draggedBlock = block
                    }
                )
                .onHover { isHovered in
                    if isHovered {
                        hoveredBlockId = block.id
                    } else if hoveredBlockId == block.id {
                        hoveredBlockId = nil
                    }
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
    let onStartDrag: () -> Void

    @State private var textBuffer: String = ""
    @State private var isSlashCommandOpen: Bool = false

    var slashQuery: String {
        if textBuffer.hasPrefix("/") {
            return String(textBuffer.dropFirst()).trimmingCharacters(in: .whitespaces).lowercased()
        }
        return ""
    }

    var filteredSlashCommands: [SlashCommandItem] {
        if slashQuery.isEmpty {
            return allSlashCommands
        }
        return allSlashCommands.filter { cmd in
            cmd.title.lowercased().contains(slashQuery) ||
            cmd.desc.lowercased().contains(slashQuery) ||
            cmd.keywords.contains { $0.lowercased().contains(slashQuery) }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .top, spacing: 4) {
                // Left Notion Gutter: [+] and [::] (width: 44pt)
                leftGutterControls
                    .padding(.top, topGutterPadding)

                // Main Block Content Body
                blockContentBody
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Inline Filtered Notion Slash Command Palette
            if isSlashCommandOpen {
                slashCommandPaletteView
                    .padding(.leading, 48)
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

    // MARK: - Left Gutter Controls: [+] and [::] (Both fully visible & functional)

    private var leftGutterControls: some View {
        HStack(spacing: 4) {
            // "+" Add Block Below Menu
            Menu {
                allBlocksInsertionMenu
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 18, height: 18)
                    .background(Color.primary.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .help("Click to add block below")

            // "::" Drag Handle & Context Menu
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
                    .frame(width: 18, height: 18)
                    .background(Color.primary.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .help("Drag to rearrange or click for block options")
            .onDrag {
                onStartDrag()
                return NSItemProvider(object: block.id as NSString)
            }
        }
        .frame(width: 44)
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
                onSlashCommit: handleSlashCommit,
                onEscape: { isSlashCommandOpen = false; return true },
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
                onSlashCommit: handleSlashCommit,
                onEscape: { isSlashCommandOpen = false; return true },
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
                    onSlashCommit: handleSlashCommit,
                    onEscape: { isSlashCommandOpen = false; return true },
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
                    onSlashCommit: handleSlashCommit,
                    onEscape: { isSlashCommandOpen = false; return true },
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
                        onSlashCommit: handleSlashCommit,
                        onEscape: { isSlashCommandOpen = false; return true },
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
                    onSlashCommit: handleSlashCommit,
                    onEscape: { isSlashCommandOpen = false; return true },
                    onTextChanged: checkSlashCommand
                )
            }
            .padding(.vertical, 2)

        // 7. Divider Block (With hover delete action)
        case .divider:
            HStack(spacing: 8) {
                Divider()
                    .frame(height: 1)

                if isHovered {
                    Button(role: .destructive, action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 10))
                            .foregroundStyle(.red.opacity(0.75))
                    }
                    .buttonStyle(.plain)
                    .help("Delete Divider")
                }
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())

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
                    onSlashCommit: handleSlashCommit,
                    onEscape: { isSlashCommandOpen = false; return true },
                    onTextChanged: checkSlashCommand
                )
            }

        // 9. Callout Box (Editable text, emoji & theme menu, and delete button)
        case .callout(let icon, let theme):
            HStack(alignment: .top, spacing: 10) {
                Menu {
                    ForEach(["💡", "⚠️", "✅", "🎯", "🔥", "📌", "🚀", "💬", "⭐️", "⚡️"], id: \.self) { emoji in
                        Button(emoji) {
                            onTransformKind(.callout(icon: emoji, theme: theme))
                        }
                    }
                    Divider()
                    ForEach(BlockColorTheme.allCases, id: \.self) { t in
                        Button("Theme: \(t.rawValue)") {
                            onTransformKind(.callout(icon: icon, theme: t))
                        }
                    }
                } label: {
                    Text(icon)
                        .font(.system(size: 18))
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)

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
                    onSlashCommit: handleSlashCommit,
                    onEscape: { isSlashCommandOpen = false; return true },
                    onTextChanged: checkSlashCommand
                )

                if isHovered {
                    Button(role: .destructive, action: onDelete) {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundStyle(.red.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    .help("Delete Callout")
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

        // 10. Web Bookmark / Link Card (Fully editable title & URL, Open, and Delete)
        case .bookmark(let url):
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: "link.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.tint)

                    // Editable Title
                    BlockEditorField(
                        text: $textBuffer,
                        placeholder: "Bookmark Title...",
                        font: NSFont.systemFont(ofSize: 14, weight: .semibold),
                        textColor: .labelColor,
                        isFocused: isFocused,
                        onCommit: {
                            onInsertBelow(.paragraph, "")
                        },
                        onDeleteEmpty: onDeleteEmpty,
                        onSlashCommit: handleSlashCommit,
                        onEscape: { isSlashCommandOpen = false; return true },
                        onTextChanged: checkSlashCommand
                    )

                    Spacer()

                    if let validUrl = URL(string: url), !url.isEmpty, url != "https://" {
                        Button(action: {
                            NSWorkspace.shared.open(validUrl)
                        }) {
                            HStack(spacing: 3) {
                                Image(systemName: "arrow.up.right")
                                    .font(.caption2)
                                Text("Open")
                                    .font(.caption2)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.primary.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                        .buttonStyle(.plain)
                    }

                    Button(role: .destructive, action: onDelete) {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundStyle(.red.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    .help("Delete Bookmark")
                }

                // Editable URL
                HStack(spacing: 6) {
                    Image(systemName: "globe")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    TextField("https://...", text: Binding(
                        get: { url },
                        set: { newUrl in
                            onTransformKind(.bookmark(url: newUrl))
                        }
                    ))
                    .textFieldStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(10)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )

        // 11. Image Block (Preview, URL, Caption & Delete)
        case .image(let url, let caption):
            VStack(alignment: .leading, spacing: 6) {
                if !url.isEmpty, let imgUrl = URL(string: url) {
                    AsyncImage(url: imgUrl) { phase in
                        switch phase {
                        case .empty:
                            HStack {
                                ProgressView().controlSize(.small)
                                Text("Loading image...")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 120)
                            .background(Color.secondary.opacity(0.05))
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 280)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        case .failure:
                            VStack(spacing: 4) {
                                Image(systemName: "photo.badge.exclamationmark")
                                    .font(.title3)
                                    .foregroundStyle(.secondary)
                                Text("Could not load image from URL")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 90)
                            .background(Color.secondary.opacity(0.05))
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }

                HStack(spacing: 8) {
                    Image(systemName: "photo")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    TextField("Image URL (https://...)", text: Binding(
                        get: { url },
                        set: { newUrl in
                            onTransformKind(.image(url: newUrl, caption: caption))
                        }
                    ))
                    .textFieldStyle(.plain)
                    .font(.caption)

                    Spacer()

                    Button(role: .destructive, action: onDelete) {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundStyle(.red.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    .help("Delete Image")
                }

                BlockEditorField(
                    text: $textBuffer,
                    placeholder: "Add a caption (optional)...",
                    font: NSFont.systemFont(ofSize: 13),
                    textColor: .secondaryLabelColor,
                    isFocused: isFocused,
                    onCommit: {
                        onInsertBelow(.paragraph, "")
                    },
                    onDeleteEmpty: onDeleteEmpty,
                    onSlashCommit: handleSlashCommit,
                    onEscape: { isSlashCommandOpen = false; return true },
                    onTextChanged: { newCap in
                        onTransformKind(.image(url: url, caption: newCap))
                        onUpdateText(newCap)
                    }
                )
            }
            .padding(10)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )

        // 12. Math / Equation (LaTeX / Typst Formula & Preview)
        case .math(let expression):
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("MATH FORMULA")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button(role: .destructive, action: onDelete) {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundStyle(.red.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    .help("Delete Math Block")
                }

                BlockEditorField(
                    text: $textBuffer,
                    placeholder: "e.g. E = mc^2 or \\int_0^\\infty e^{-x} dx",
                    font: NSFont.monospacedSystemFont(ofSize: 14, weight: .regular),
                    textColor: .labelColor,
                    isFocused: isFocused,
                    onCommit: {
                        onInsertBelow(.paragraph, "")
                    },
                    onDeleteEmpty: onDeleteEmpty,
                    onSlashCommit: handleSlashCommit,
                    onEscape: { isSlashCommandOpen = false; return true },
                    onTextChanged: { newExpr in
                        onTransformKind(.math(expression: newExpr))
                        onUpdateText(newExpr)
                    }
                )

                if !textBuffer.isEmpty {
                    HStack {
                        Spacer()
                        Text(textBuffer)
                            .font(.system(size: 16, design: .serif).italic())
                            .foregroundStyle(.primary)
                            .padding(.vertical, 6)
                        Spacer()
                    }
                    .background(Color.primary.opacity(0.03))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
            .padding(10)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )

        // 13. Code Block (Multi-line, Language Tag, Copy & Delete)
        case .code(let lang):
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Menu {
                        ForEach(["rust", "swift", "python", "javascript", "typescript", "html", "css", "json", "shell", "typst"], id: \.self) { l in
                            Button(l.uppercased()) {
                                onTransformKind(.code(lang: l))
                            }
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Text(lang.uppercased())
                                .font(.system(size: 11, weight: .bold))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 8, weight: .bold))
                        }
                        .foregroundStyle(.secondary)
                    }
                    .menuStyle(.borderlessButton)

                    Spacer()

                    Button("Copy") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(textBuffer, forType: .string)
                    }
                    .buttonStyle(.borderless)
                    .font(.caption2)

                    Button(role: .destructive, action: onDelete) {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundStyle(.red.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    .help("Delete Code Block")
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

        // 14. Grid / Table (Editable columns, Add Column, Delete)
        case .grid(let columns):
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top, spacing: 10) {
                    ForEach(Array(columns.enumerated()), id: \.offset) { colIdx, colText in
                        TextField("Column \(colIdx + 1)", text: Binding(
                            get: { colText },
                            set: { newColVal in
                                var mutableCols = columns
                                mutableCols[colIdx] = newColVal
                                onTransformKind(.grid(columns: mutableCols))
                            }
                        ))
                        .textFieldStyle(.plain)
                        .font(.subheadline)
                        .padding(8)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
                        )
                    }
                }

                HStack {
                    Button(action: {
                        var mutableCols = columns
                        mutableCols.append("New Column")
                        onTransformKind(.grid(columns: mutableCols))
                    }) {
                        Label("Add Column", systemImage: "plus")
                            .font(.caption2)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Button(role: .destructive, action: onDelete) {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundStyle(.red.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    .help("Delete Table")
                }
            }
            .padding(8)
        }
    }

    private func checkSlashCommand(_ text: String) {
        if text.hasPrefix("/") {
            isSlashCommandOpen = true
        } else {
            isSlashCommandOpen = false
        }
        onUpdateText(text)
    }

    private func handleSlashCommit() -> Bool {
        if isSlashCommandOpen && !filteredSlashCommands.isEmpty {
            applySlashCommand(filteredSlashCommands.first!.kind)
            return true
        }
        return false
    }

    // MARK: - Filtered Notion Slash Command Palette View

    private var slashCommandPaletteView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 3) {
                if filteredSlashCommands.isEmpty {
                    Text("No commands found for '/\(slashQuery)'")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(12)
                } else {
                    Text("COMMANDS (\(filteredSlashCommands.count))")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 8)
                        .padding(.top, 4)

                    ForEach(Array(filteredSlashCommands.enumerated()), id: \.element.id) { cmdIdx, cmd in
                        Button(action: {
                            applySlashCommand(cmd.kind)
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: cmd.icon)
                                    .font(.system(size: 13))
                                    .foregroundStyle(.tint)
                                    .frame(width: 20)

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(cmd.title)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(.primary)

                                    Text(cmd.desc)
                                        .font(.system(size: 10))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }

                                Spacer()

                                if cmdIdx == 0 {
                                    Text("↵ Enter")
                                        .font(.system(size: 9, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(Color.primary.opacity(0.06))
                                        .clipShape(RoundedRectangle(cornerRadius: 3))
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(cmdIdx == 0 ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.04))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(6)
        }
        .frame(width: 310, height: min(CGFloat(max(1, filteredSlashCommands.count)) * 44 + 30, 320))
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: Color.black.opacity(0.18), radius: 12, y: 5)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
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
        Section("Media & Advanced") {
            Button("Code Block") { onInsertBelow(.code(lang: "rust"), "") }
            Button("Web Bookmark") { onInsertBelow(.bookmark(url: "https://apple.com"), "Apple") }
            Button("Image") { onInsertBelow(.image(url: "", caption: ""), "") }
            Button("Math / Equation") { onInsertBelow(.math(expression: ""), "") }
            Button("Table / Grid") { onInsertBelow(.grid(columns: ["Column 1", "Column 2", "Column 3"]), "") }
        }
    }

    @ViewBuilder
    private var allBlocksTransformMenu: some View {
        Section("Turn Into") {
            Button("Text") { onTransformKind(.paragraph) }
            Button("Heading 1") { onTransformKind(.heading(level: 1)) }
            Button("Heading 2") { onTransformKind(.heading(level: 2)) }
            Button("Heading 3") { onTransformKind(.heading(level: 3)) }
            Button("To-do List") { onTransformKind(.todo(checked: false)) }
            Button("Bulleted List") { onTransformKind(.bullet) }
            Button("Numbered List") { onTransformKind(.numbered(index: 1)) }
            Button("Toggle List") { onTransformKind(.toggle(isExpanded: false)) }
            Button("Quote") { onTransformKind(.quote) }
            Button("Divider") { onTransformKind(.divider) }
            Button("Info Callout (💡)") { onTransformKind(.callout(icon: "💡", theme: .blue)) }
            Button("Warning Callout (⚠️)") { onTransformKind(.callout(icon: "⚠️", theme: .red)) }
            Button("Tip Callout (✅)") { onTransformKind(.callout(icon: "✅", theme: .green)) }
            Button("Code Block") { onTransformKind(.code(lang: "rust")) }
            Button("Web Bookmark") { onTransformKind(.bookmark(url: "https://apple.com")) }
            Button("Image") { onTransformKind(.image(url: "", caption: "")) }
            Button("Math Formula") { onTransformKind(.math(expression: "")) }
        }
    }

    private var topGutterPadding: CGFloat {
        switch block.kind {
        case .heading(1): return 7
        case .heading(2): return 5
        case .heading(3): return 4
        case .callout: return 12
        case .code: return 12
        case .bookmark: return 12
        case .image: return 12
        case .math: return 12
        case .grid: return 12
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
