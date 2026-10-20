import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - Vibrant Preset Gradients (Zero Network Delay)

enum PresetGradientCover: String, CaseIterable, Identifiable {
    case sunset = "gradient:sunset"
    case ocean = "gradient:ocean"
    case aurora = "gradient:aurora"
    case midnight = "gradient:midnight"
    case blush = "gradient:blush"
    case emerald = "gradient:emerald"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sunset: return "Sunset"
        case .ocean: return "Ocean"
        case .aurora: return "Aurora"
        case .midnight: return "Midnight"
        case .blush: return "Blush"
        case .emerald: return "Emerald"
        }
    }

    var colors: [Color] {
        switch self {
        case .sunset:
            return [Color(red: 0.96, green: 0.45, blue: 0.28), Color(red: 0.68, green: 0.22, blue: 0.78)]
        case .ocean:
            return [Color(red: 0.12, green: 0.42, blue: 0.88), Color(red: 0.22, green: 0.82, blue: 0.78)]
        case .aurora:
            return [Color(red: 0.08, green: 0.72, blue: 0.52), Color(red: 0.32, green: 0.22, blue: 0.78)]
        case .midnight:
            return [Color(red: 0.12, green: 0.12, blue: 0.28), Color(red: 0.38, green: 0.18, blue: 0.52)]
        case .blush:
            return [Color(red: 0.96, green: 0.38, blue: 0.48), Color(red: 0.96, green: 0.72, blue: 0.38)]
        case .emerald:
            return [Color(red: 0.05, green: 0.55, blue: 0.42), Color(red: 0.15, green: 0.78, blue: 0.55)]
        }
    }

    static func colors(for raw: String) -> [Color] {
        if let match = PresetGradientCover.allCases.first(where: { $0.rawValue == raw }) {
            return match.colors
        }
        return [Color.accentColor.opacity(0.8), Color.purple.opacity(0.8)]
    }
}

// MARK: - Focusable Title Text Field

class FocusableTitleTextField: NSTextField {
    var onDidBecomeFirstResponder: (() -> Void)?

    override func becomeFirstResponder() -> Bool {
        let ok = super.becomeFirstResponder()
        if ok {
            onDidBecomeFirstResponder?()
        }
        return ok
    }

    override func mouseDown(with event: NSEvent) {
        onDidBecomeFirstResponder?()
        super.mouseDown(with: event)
    }
}

// MARK: - Native Title Editor Field (Supports Enter to Jump to Content)

struct TitleEditorField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var onCommit: () -> Void
    var onTextChanged: (String) -> Void
    var onBeginEditing: (() -> Void)? = nil

    func makeNSView(context: Context) -> NSTextField {
        let tf = FocusableTitleTextField()
        tf.isBordered = false
        tf.drawsBackground = false
        tf.focusRingType = .none
        tf.font = NSFont.systemFont(ofSize: 34, weight: .bold)
        tf.textColor = .labelColor
        tf.placeholderString = placeholder
        tf.delegate = context.coordinator
        tf.cell?.wraps = true
        tf.cell?.isScrollable = false
        tf.maximumNumberOfLines = 2
        tf.lineBreakMode = .byWordWrapping
        tf.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        tf.setAccessibilityLabel("Document Title")
        tf.setAccessibilityRole(.textField)

        tf.onDidBecomeFirstResponder = {
            context.coordinator.parent.onBeginEditing?()
        }
        return tf
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        nsView.placeholderString = placeholder
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: TitleEditorField

        init(_ parent: TitleEditorField) {
            self.parent = parent
        }

        func controlTextDidBeginEditing(_ obj: Notification) {
            parent.onBeginEditing?()
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let tf = obj.object as? NSTextField else { return }
            parent.text = tf.stringValue
            parent.onTextChanged(tf.stringValue)
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                parent.onCommit()
                return true
            }
            return false
        }
    }
}

// MARK: - Document Canvas View

struct DocumentCanvasView: View {
    @ObservedObject var store: WorkspaceStore
    let page: DocumentPage

    @State private var titleBuffer: String = ""
    @State private var focusedBlockId: String? = nil
    @State private var selectedBlockIds: Set<String> = []
    @State private var blockActionTrigger: BlockActionCommand? = nil
    @State private var formattingState = EditorFormattingState()
    @State private var isIconPickerOpen: Bool = false
    @State private var isCoverPickerOpen: Bool = false
    @State private var isStatsPopoverOpen: Bool = false
    @State private var isCoverHovered: Bool = false
    @State private var isHeaderHovered: Bool = false
    @State private var customEmojiInput: String = ""
    @State private var customCoverUrlInput: String = ""

    var currentPage: DocumentPage {
        store.pages.first(where: { $0.id == page.id }) ?? page
    }

    // MARK: - Document Statistics

    private var wordCount: Int {
        let text = currentPage.rawContent
        let words = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        return words.count
    }

    private var characterCount: Int {
        currentPage.rawContent.count
    }

    private var readingTimeMinutes: Int {
        max(1, Int(ceil(Double(wordCount) / 200.0)))
    }

    private var blockCount: Int {
        store.parseToUIBlocks(content: currentPage.rawContent).count
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ZStack(alignment: .trailing) {
                documentCanvasBody

                if store.isPreviewDrawerPresented {
                    HStack(spacing: 0) {
                        Divider()
                        TypstPreviewView(
                            svgString: store.currentSvg,
                            onClose: { store.isPreviewDrawerPresented = false }
                        )
                        .frame(width: 440)
                        .background(Color(nsColor: .windowBackgroundColor))
                        .shadow(color: Color.black.opacity(0.12), radius: 8, x: -4)
                    }
                    .transition(.move(edge: .trailing))
                }
            }

            // Floating Action Toolbar (Notion & Bear style glassmorphic island)
            if !selectedBlockIds.isEmpty {
                floatingSelectionToolbar
                    .padding(.bottom, 22)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.95).combined(with: .opacity),
                        removal: .scale(scale: 0.95).combined(with: .opacity)
                    ))
            } else {
                floatingEditorToolbar
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.95).combined(with: .opacity),
                        removal: .scale(scale: 0.95).combined(with: .opacity)
                    ))
            }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.8), value: selectedBlockIds.isEmpty)
        .background(
            Group {
                Button("") {
                    blockActionTrigger = .selectAll
                }
                .keyboardShortcut("a", modifiers: .command)

                Button("") {
                    if !selectedBlockIds.isEmpty {
                        blockActionTrigger = .deleteSelected
                    }
                }
                .keyboardShortcut(.delete, modifiers: [])

                Button("") {
                    if !selectedBlockIds.isEmpty {
                        blockActionTrigger = .deleteSelected
                    }
                }
                .keyboardShortcut(.deleteForward, modifiers: [])

                Button("") {
                    if !selectedBlockIds.isEmpty {
                        selectedBlockIds.removeAll()
                    }
                }
                .keyboardShortcut(.escape, modifiers: [])

                Button("") {
                    if !selectedBlockIds.isEmpty {
                        blockActionTrigger = .duplicateSelected
                    }
                }
                .keyboardShortcut("d", modifiers: .command)

                Button("") {
                    blockActionTrigger = .formatActiveBlock("**")
                }
                .keyboardShortcut("b", modifiers: .command)

                Button("") {
                    blockActionTrigger = .formatActiveBlock("*")
                }
                .keyboardShortcut("i", modifiers: .command)

                Button("") {
                    blockActionTrigger = .formatActiveBlock("~~")
                }
                .keyboardShortcut("x", modifiers: [.command, .shift])

                Button("") {
                    blockActionTrigger = .formatActiveBlock("`")
                }
                .keyboardShortcut("e", modifiers: .command)

                Button("") {
                    store.revealInFinder(pageId: currentPage.id)
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
            }
            .opacity(0)
            .frame(width: 0, height: 0)
        )
        .navigationTitle(currentPage.title.isEmpty ? "Untitled" : currentPage.title)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 6) {
                    if !currentPage.icon.isEmpty {
                        Text(currentPage.icon)
                            .font(.system(size: 14))
                    } else {
                        Image(systemName: "doc.text")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }

                    Text(currentPage.title.isEmpty ? "Untitled" : currentPage.title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(currentPage.title.isEmpty ? .secondary : .primary)
                        .lineLimit(1)
                }
            }

            ToolbarItemGroup(placement: .primaryAction) {
                // 1. Quick Insert Menu
                Menu {
                    Section("Basic Blocks") {
                        Button("Text Paragraph") { blockActionTrigger = .insertBlock(.paragraph) }
                        Button("Heading 1") { blockActionTrigger = .insertBlock(.heading(level: 1)) }
                        Button("Heading 2") { blockActionTrigger = .insertBlock(.heading(level: 2)) }
                        Button("Heading 3") { blockActionTrigger = .insertBlock(.heading(level: 3)) }
                    }
                    Section("Lists") {
                        Button("To-do List") { blockActionTrigger = .insertBlock(.todo(checked: false)) }
                        Button("Bulleted List") { blockActionTrigger = .insertBlock(.bullet) }
                        Button("Numbered List") { blockActionTrigger = .insertBlock(.numbered(index: 1)) }
                        Button("Toggle List") { blockActionTrigger = .insertBlock(.toggle(isExpanded: false)) }
                    }
                    Section("Quotes & Callouts") {
                        Button("Quote") { blockActionTrigger = .insertBlock(.quote) }
                        Button("Info Callout (💡)") { blockActionTrigger = .insertBlock(.callout(icon: "💡", theme: .blue)) }
                        Button("Warning Callout (⚠️)") { blockActionTrigger = .insertBlock(.callout(icon: "⚠️", theme: .red)) }
                        Button("Tip Callout (✅)") { blockActionTrigger = .insertBlock(.callout(icon: "✅", theme: .green)) }
                    }
                    Section("Data & Media") {
                        Button("Table / Grid") {
                            blockActionTrigger = .insertBlock(.grid(
                                headers: ["Column 1", "Column 2", "Column 3"],
                                rows: [["", "", ""], ["", "", ""]]
                            ))
                        }
                        Button("Code Block") { blockActionTrigger = .insertBlock(.code(lang: "rust")) }
                        Button("Math Equation") { blockActionTrigger = .insertBlock(.math(expression: "")) }
                        Button("Web Bookmark") { blockActionTrigger = .insertBlock(.bookmark(url: "https://apple.com")) }
                        Button("Image") { blockActionTrigger = .insertBlock(.image(url: "", caption: "")) }
                        Button("Divider") { blockActionTrigger = .insertBlock(.divider) }
                    }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Insert")
                            .font(.system(size: 12, weight: .medium))
                    }
                }
                .help("Insert block into document")

                // 2. Formatting Control Group with Live Active Indicators
                HStack(spacing: 2) {
                    topToolbarFormatButton(icon: "bold", isActive: formattingState.isBold, help: "Bold (⌘B)") {
                        blockActionTrigger = .formatActiveBlock("**")
                    }
                    topToolbarFormatButton(icon: "italic", isActive: formattingState.isItalic, help: "Italic (⌘I)") {
                        blockActionTrigger = .formatActiveBlock("*")
                    }
                    topToolbarFormatButton(icon: "strikethrough", isActive: formattingState.isStrike, help: "Strikethrough") {
                        blockActionTrigger = .formatActiveBlock("~~")
                    }
                    topToolbarFormatButton(icon: "curlybraces", isActive: formattingState.isCode, help: "Inline Code") {
                        blockActionTrigger = .formatActiveBlock("`")
                    }
                }
                .padding(2)
                .background(Color.primary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 6))

                // 3. Quick Table Shortcut Button
                Button(action: {
                    blockActionTrigger = .insertBlock(.grid(
                        headers: ["Column 1", "Column 2", "Column 3"],
                        rows: [["", "", ""], ["", "", ""]]
                    ))
                }) {
                    Image(systemName: "tablecells")
                        .font(.system(size: 12))
                }
                .help("Insert Table")

                // 4. Quick Checklist Shortcut Button
                Button(action: {
                    blockActionTrigger = .insertBlock(.todo(checked: false))
                }) {
                    Image(systemName: "checkmark.square")
                        .font(.system(size: 12))
                }
                .help("Insert To-do item")

                // 5. Live Document Stats Pill
                Button(action: { isStatsPopoverOpen.toggle() }) {
                    HStack(spacing: 3) {
                        Image(systemName: "chart.bar.doc.horizontal")
                            .font(.system(size: 11))
                        Text("\(wordCount)w")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                    }
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.primary.opacity(0.04))
                .clipShape(Capsule())
                .help("Document Statistics")
                .popover(isPresented: $isStatsPopoverOpen) {
                    statsPopoverView
                }

                // 6. Live Typst Preview Toggle
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        store.isPreviewDrawerPresented.toggle()
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 12))
                        Text("Preview")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(store.isPreviewDrawerPresented ? Color.accentColor.opacity(0.18) : Color.clear)
                    .foregroundStyle(store.isPreviewDrawerPresented ? Color.accentColor : Color.secondary)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .help("Toggle Typst Vector Preview (⌘P)")

                // 7. Share & Export Menu
                Menu {
                    Button(action: { exportDocument(format: "md") }) {
                        Label("Export as Markdown (.md)", systemImage: "arrow.down.doc")
                    }
                    Button(action: { exportDocument(format: "typ") }) {
                        Label("Export as Typst (.typ)", systemImage: "arrow.down.doc.fill")
                    }
                    Divider()
                    Button(action: {
                        NSPasteboard.general.clearContents()
                        let md = "# \(currentPage.title)\n\n\(currentPage.rawContent)"
                        NSPasteboard.general.setString(md, forType: .string)
                    }) {
                        Label("Copy Full Markdown", systemImage: "doc.on.doc")
                    }
                    if !store.currentSvg.isEmpty {
                        Button(action: {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(store.currentSvg, forType: .string)
                        }) {
                            Label("Copy Typst SVG Vector", systemImage: "sparkle.magnifyingglass")
                        }
                    }
                    Divider()
                    Button(action: { store.revealInFinder(pageId: currentPage.id) }) {
                        Label("Reveal in Finder (Obsidian Vault)", systemImage: "folder")
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 12))
                }
                .help("Export & Share Document")

                // 8. Page Options Menu (...)
                Menu {
                    Button(action: { isCoverPickerOpen = true }) {
                        Label(currentPage.coverUrl.isEmpty ? "Add Cover" : "Change Cover", systemImage: "photo")
                    }
                    Button(action: { isIconPickerOpen = true }) {
                        Label(currentPage.icon.isEmpty ? "Add Icon" : "Change Icon", systemImage: "face.smiling")
                    }
                    Divider()
                    Button(action: { store.revealInFinder(pageId: currentPage.id) }) {
                        Label("Reveal in Finder (Obsidian Vault)", systemImage: "folder")
                    }
                    Divider()
                    Button(action: { store.duplicatePage(id: currentPage.id) }) {
                        Label("Duplicate Page", systemImage: "plus.square.on.square")
                    }
                    Button(action: { store.toggleFavorite(id: currentPage.id) }) {
                        Label(
                            currentPage.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                            systemImage: currentPage.isFavorite ? "star.fill" : "star"
                        )
                    }
                    Button(action: {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(currentPage.title.isEmpty ? "Untitled" : currentPage.title, forType: .string)
                    }) {
                        Label("Copy Page Title", systemImage: "text.quote")
                    }
                    Divider()
                    Button(role: .destructive, action: { store.deletePage(id: currentPage.id) }) {
                        Label("Move to Trash", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .help("Page Options")
            }
        }
        .onAppear {
            self.titleBuffer = currentPage.title
        }
        .onChange(of: page.id) { _, _ in
            self.titleBuffer = currentPage.title
        }
    }

    // MARK: - Export Action

    private func exportDocument(format: String) {
        let panel = NSSavePanel()
        panel.title = "Export Document"
        let safeTitle = currentPage.title.trimmingCharacters(in: .whitespaces).isEmpty ? "Untitled" : currentPage.title
        panel.nameFieldStringValue = "\(safeTitle).\(format)"
        panel.allowedContentTypes = [UTType(filenameExtension: format) ?? .plainText]
        panel.canCreateDirectories = true

        let content: String
        if format == "typ" {
            content = "= \(currentPage.title)\n\n\(currentPage.rawContent)"
        } else {
            content = "# \(currentPage.title)\n\n\(currentPage.rawContent)"
        }

        if panel.runModal() == .OK, let url = panel.url {
            try? content.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    private func focusFirstBlock() {
        let blocks = store.parseToUIBlocks(content: currentPage.rawContent)
        if let first = blocks.first {
            focusedBlockId = nil
            DispatchQueue.main.async {
                self.focusedBlockId = first.id
            }
        }
    }

    // MARK: - Document Statistics Popover

    private var statsPopoverView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Document Statistics")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.primary)

            Divider()

            HStack {
                Text("Words")
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(wordCount)")
                    .fontWeight(.semibold)
            }
            .font(.caption)

            HStack {
                Text("Characters")
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(characterCount)")
                    .fontWeight(.semibold)
            }
            .font(.caption)

            HStack {
                Text("Reading Time")
                    .foregroundStyle(.secondary)
                Spacer()
                Text("~\(readingTimeMinutes) min")
                    .fontWeight(.semibold)
            }
            .font(.caption)

            HStack {
                Text("Blocks")
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(blockCount)")
                    .fontWeight(.semibold)
            }
            .font(.caption)
        }
        .padding(14)
        .frame(width: 200)
    }

    // MARK: - Floating Editor Toolbar (Notion & Bear Glassmorphic Island)

    private var floatingEditorToolbar: some View {
        HStack(spacing: 8) {
            // 1. Quick Insert Menu Button
            Menu {
                Section("Basic Blocks") {
                    Button("Text Paragraph") { blockActionTrigger = .insertBlock(.paragraph) }
                    Button("Heading 1") { blockActionTrigger = .insertBlock(.heading(level: 1)) }
                    Button("Heading 2") { blockActionTrigger = .insertBlock(.heading(level: 2)) }
                    Button("Heading 3") { blockActionTrigger = .insertBlock(.heading(level: 3)) }
                }
                Section("Lists") {
                    Button("To-do List") { blockActionTrigger = .insertBlock(.todo(checked: false)) }
                    Button("Bulleted List") { blockActionTrigger = .insertBlock(.bullet) }
                    Button("Numbered List") { blockActionTrigger = .insertBlock(.numbered(index: 1)) }
                    Button("Toggle List") { blockActionTrigger = .insertBlock(.toggle(isExpanded: false)) }
                }
                Section("Callouts & Quotes") {
                    Button("Quote") { blockActionTrigger = .insertBlock(.quote) }
                    Button("Info Callout (💡)") { blockActionTrigger = .insertBlock(.callout(icon: "💡", theme: .blue)) }
                    Button("Warning Callout (⚠️)") { blockActionTrigger = .insertBlock(.callout(icon: "⚠️", theme: .red)) }
                    Button("Tip Callout (✅)") { blockActionTrigger = .insertBlock(.callout(icon: "✅", theme: .green)) }
                }
                Section("Media & Data") {
                    Button("Table / Grid") {
                        blockActionTrigger = .insertBlock(.grid(
                            headers: ["Column 1", "Column 2", "Column 3"],
                            rows: [["", "", ""], ["", "", ""]]
                        ))
                    }
                    Button("Code Block") { blockActionTrigger = .insertBlock(.code(lang: "rust")) }
                    Button("Math Equation") { blockActionTrigger = .insertBlock(.math(expression: "")) }
                    Button("Web Bookmark") { blockActionTrigger = .insertBlock(.bookmark(url: "https://apple.com")) }
                    Button("Image") { blockActionTrigger = .insertBlock(.image(url: "", caption: "")) }
                    Button("Divider") { blockActionTrigger = .insertBlock(.divider) }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .bold))
                    Text("Add")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(.primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color.primary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .help("Insert block")

            // 2. Turn into Menu
            Menu {
                Section("Turn into") {
                    Button("Text") { blockActionTrigger = .transformSelected(.paragraph) }
                    Button("Heading 1") { blockActionTrigger = .transformSelected(.heading(level: 1)) }
                    Button("Heading 2") { blockActionTrigger = .transformSelected(.heading(level: 2)) }
                    Button("Heading 3") { blockActionTrigger = .transformSelected(.heading(level: 3)) }
                    Divider()
                    Button("To-do List") { blockActionTrigger = .transformSelected(.todo(checked: false)) }
                    Button("Bulleted List") { blockActionTrigger = .transformSelected(.bullet) }
                    Button("Numbered List") { blockActionTrigger = .transformSelected(.numbered(index: 1)) }
                    Button("Quote") { blockActionTrigger = .transformSelected(.quote) }
                    Button("Code Block") { blockActionTrigger = .transformSelected(.code(lang: "rust")) }
                    Button("Table / Grid") {
                        blockActionTrigger = .transformSelected(.grid(
                            headers: ["Column 1", "Column 2", "Column 3"],
                            rows: [["", "", ""], ["", "", ""]]
                        ))
                    }
                }
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 10))
                    Text("Style")
                        .font(.system(size: 12, weight: .medium))
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 7))
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 5)
                .background(Color.primary.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .help("Change block type")

            Divider().frame(height: 16)

            // 3. Formatting Buttons with Live Active Indicators
            HStack(spacing: 2) {
                toolbarButton(icon: "bold", isActive: formattingState.isBold, help: "Bold (⌘B)") {
                    blockActionTrigger = .formatActiveBlock("**")
                }
                toolbarButton(icon: "italic", isActive: formattingState.isItalic, help: "Italic (⌘I)") {
                    blockActionTrigger = .formatActiveBlock("*")
                }
                toolbarButton(icon: "strikethrough", isActive: formattingState.isStrike, help: "Strikethrough") {
                    blockActionTrigger = .formatActiveBlock("~~")
                }
                toolbarButton(icon: "curlybraces", isActive: formattingState.isCode, help: "Inline Code") {
                    blockActionTrigger = .formatActiveBlock("`")
                }
            }

            Divider().frame(height: 16)

            // 4. Quick Action Shortcuts
            HStack(spacing: 2) {
                toolbarButton(icon: "tablecells", help: "Insert Table") {
                    blockActionTrigger = .insertBlock(.grid(
                        headers: ["Column 1", "Column 2", "Column 3"],
                        rows: [["", "", ""], ["", "", ""]]
                    ))
                }
                toolbarButton(icon: "checkmark.square", help: "Insert To-do") {
                    blockActionTrigger = .insertBlock(.todo(checked: false))
                }
                toolbarButton(icon: "text.quote", help: "Insert Quote") {
                    blockActionTrigger = .insertBlock(.quote)
                }
            }

            Divider().frame(height: 16)

            // 5. Live Document Reading Stats
            HStack(spacing: 5) {
                Text("\(wordCount) w")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
                Text("•")
                    .font(.system(size: 8))
                    .foregroundStyle(.tertiary)
                Text("~\(readingTimeMinutes)m")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 4)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(.ultraThickMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.16), radius: 14, y: 5)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
        .padding(.bottom, 22)
    }

    @ViewBuilder
    private func topToolbarFormatButton(icon: String, isActive: Bool, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: isActive ? .bold : .medium))
                .foregroundStyle(isActive ? Color.accentColor : Color.secondary)
                .frame(width: 24, height: 20)
                .background(isActive ? Color.accentColor.opacity(0.22) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isActive ? Color.accentColor.opacity(0.4) : Color.clear, lineWidth: 1)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }

    @ViewBuilder
    private func toolbarButton(icon: String, isActive: Bool = false, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: isActive ? .bold : .medium))
                .foregroundStyle(isActive ? Color.accentColor : Color.secondary)
                .frame(width: 26, height: 26)
                .background(isActive ? Color.accentColor.opacity(0.22) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isActive ? Color.accentColor.opacity(0.4) : Color.clear, lineWidth: 1)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }

    // MARK: - Document Body

    private var documentCanvasBody: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 0) {
                if !currentPage.coverUrl.isEmpty {
                    pageCoverBannerView
                }

                VStack(alignment: .leading, spacing: 14) {
                    notionPageHeaderView

                    BlockListView(
                        store: store,
                        page: currentPage,
                        focusedBlockId: $focusedBlockId,
                        selectedBlockIds: $selectedBlockIds,
                        blockActionTrigger: $blockActionTrigger,
                        formattingState: $formattingState
                    )

                    Spacer(minLength: 200)
                }
                .frame(maxWidth: 920)
                .padding(.horizontal, 28)
                .padding(.top, currentPage.coverUrl.isEmpty ? 28 : 16)
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Cover Banner View

    private var pageCoverBannerView: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if currentPage.coverUrl.hasPrefix("gradient:") {
                    LinearGradient(
                        colors: PresetGradientCover.colors(for: currentPage.coverUrl),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                } else {
                    AsyncImage(url: URL(string: currentPage.coverUrl)) { phase in
                        switch phase {
                        case .empty:
                            LinearGradient(
                                colors: [Color.accentColor.opacity(0.3), Color.purple.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        case .failure:
                            LinearGradient(
                                colors: [Color.gray.opacity(0.4), Color.gray.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        @unknown default:
                            Color.secondary.opacity(0.2)
                        }
                    }
                }
            }
            .frame(height: 180)
            .frame(maxWidth: .infinity)
            .clipped()

            HStack(spacing: 8) {
                Button(action: {
                    isCoverPickerOpen = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "photo")
                            .font(.caption)
                        Text("Change cover")
                            .font(.caption.weight(.medium))
                    }
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button(action: {
                    store.updatePageCover(pageId: currentPage.id, newCoverUrl: "")
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "trash")
                            .font(.caption)
                        Text("Remove")
                            .font(.caption.weight(.medium))
                    }
                    .foregroundStyle(.red)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(14)
            .opacity((isCoverHovered || isCoverPickerOpen) ? 1.0 : 0.0)
            .animation(.easeInOut(duration: 0.15), value: isCoverHovered || isCoverPickerOpen)
        }
        .contentShape(Rectangle())
        .onHover { isCoverHovered = $0 }
    }

    // MARK: - Notion Page Header

    private var notionPageHeaderView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                if currentPage.icon.isEmpty {
                    Button(action: {
                        isIconPickerOpen = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "face.smiling")
                                .font(.caption)
                            Text("Add icon")
                                .font(.caption.weight(.medium))
                        }
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.primary.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

                if currentPage.coverUrl.isEmpty {
                    Button(action: {
                        isCoverPickerOpen = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "photo")
                                .font(.caption)
                            Text("Add cover")
                                .font(.caption.weight(.medium))
                        }
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.primary.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }
            .frame(height: 24)

            if !currentPage.icon.isEmpty {
                Button(action: {
                    isIconPickerOpen = true
                }) {
                    Text(currentPage.icon)
                        .font(.system(size: 44))
                        .padding(4)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Click to change or remove icon")
            }

            TitleEditorField(
                text: $titleBuffer,
                placeholder: "Untitled",
                onCommit: {
                    focusFirstBlock()
                },
                onTextChanged: { newTitle in
                    store.updatePageTitle(pageId: currentPage.id, newTitle: newTitle)
                },
                onBeginEditing: {
                    focusedBlockId = nil
                    selectedBlockIds.removeAll()
                }
            )
            .padding(.top, 2)
        }
        .padding(.leading, 48)
        .contentShape(Rectangle())
        .onHover { isHeaderHovered = $0 }
        .popover(isPresented: $isIconPickerOpen) {
            iconPickerPopover
        }
        .popover(isPresented: $isCoverPickerOpen) {
            coverPickerPopover
        }
    }

    // MARK: - Icon Picker Popover

    private var iconPickerPopover: some View {
        let curatedEmojis = [
            "📄", "📝", "💡", "🚀", "🎯", "⚡️", "💻", "🔥",
            "✨", "📌", "🎨", "🧩", "📚", "☕️", "🛠️", "📦",
            "⭐️", "🤖", "🌿", "🌊", "🏔️", "🔍", "📊", "🧠",
            "❤️", "☀️", "🌙", "🎵", "🏆", "🔒", "💬", "✅"
        ]

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Select Icon")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                Spacer()

                if !currentPage.icon.isEmpty {
                    Button(action: {
                        store.updatePageIcon(pageId: currentPage.id, newIcon: "")
                        isIconPickerOpen = false
                    }) {
                        Text("Remove")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.fixed(32), spacing: 6), count: 8), spacing: 6) {
                ForEach(curatedEmojis, id: \.self) { emoji in
                    Button(action: {
                        store.updatePageIcon(pageId: currentPage.id, newIcon: emoji)
                        isIconPickerOpen = false
                    }) {
                        Text(emoji)
                            .font(.system(size: 20))
                            .frame(width: 32, height: 32)
                            .background(currentPage.icon == emoji ? Color.accentColor.opacity(0.25) : Color.primary.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    TextField("Paste or type emoji...", text: $customEmojiInput)
                        .textFieldStyle(.plain)
                        .font(.subheadline)
                        .padding(6)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        )
                        .onSubmit {
                            let trimmed = customEmojiInput.trimmingCharacters(in: .whitespaces)
                            if !trimmed.isEmpty {
                                store.updatePageIcon(pageId: currentPage.id, newIcon: trimmed)
                                customEmojiInput = ""
                                isIconPickerOpen = false
                            }
                        }

                    Button("Set") {
                        let trimmed = customEmojiInput.trimmingCharacters(in: .whitespaces)
                        if !trimmed.isEmpty {
                            store.updatePageIcon(pageId: currentPage.id, newIcon: trimmed)
                            customEmojiInput = ""
                            isIconPickerOpen = false
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)

                    Button("Random") {
                        if let random = curatedEmojis.randomElement() {
                            store.updatePageIcon(pageId: currentPage.id, newIcon: random)
                            isIconPickerOpen = false
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                Button(action: {
                    isIconPickerOpen = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        NSApplication.shared.orderFrontCharacterPalette(nil)
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "macwindow")
                            .font(.caption)
                        Text("Open Full macOS Emoji & Symbols (Ctrl+Cmd+Space)...")
                            .font(.caption)
                    }
                    .foregroundStyle(.tint)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .frame(width: 320)
    }

    // MARK: - Cover Picker Popover

    private var coverPickerPopover: some View {
        let unsplashPhotos = [
            ("Forest", "https://images.unsplash.com/photo-1470071459604-3b5ec3a7fe05?auto=format&fit=crop&w=1400&q=80"),
            ("Night Stars", "https://images.unsplash.com/photo-1519681393784-d120267933ba?auto=format&fit=crop&w=1400&q=80"),
            ("Ocean Waves", "https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=1400&q=80"),
            ("Minimal Waves", "https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?auto=format&fit=crop&w=1400&q=80"),
            ("Architecture", "https://images.unsplash.com/photo-1513694203232-719a280e022f?auto=format&fit=crop&w=1400&q=80"),
            ("Workspace", "https://images.unsplash.com/photo-1499750310107-5fef28a66643?auto=format&fit=crop&w=1400&q=80")
        ]

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Select Page Cover")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                Spacer()

                if !currentPage.coverUrl.isEmpty {
                    Button(action: {
                        store.updatePageCover(pageId: currentPage.id, newCoverUrl: "")
                        isCoverPickerOpen = false
                    }) {
                        Text("Remove Cover")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
            }

            Text("Vibrant Gradients")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.tertiary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
                ForEach(PresetGradientCover.allCases) { preset in
                    Button(action: {
                        store.updatePageCover(pageId: currentPage.id, newCoverUrl: preset.rawValue)
                        isCoverPickerOpen = false
                    }) {
                        ZStack(alignment: .bottomLeading) {
                            LinearGradient(
                                colors: preset.colors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            .frame(height: 48)
                            .clipShape(RoundedRectangle(cornerRadius: 6))

                            Text(preset.title)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(5)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }

            Text("Unsplash Photography")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.tertiary)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)], spacing: 6) {
                ForEach(unsplashPhotos, id: \.1) { name, url in
                    Button(action: {
                        store.updatePageCover(pageId: currentPage.id, newCoverUrl: url)
                        isCoverPickerOpen = false
                    }) {
                        ZStack(alignment: .bottomLeading) {
                            AsyncImage(url: URL(string: url)) { phase in
                                if let img = phase.image {
                                    img.resizable().scaledToFill()
                                } else {
                                    Color.secondary.opacity(0.15)
                                }
                            }
                            .frame(height: 50)
                            .frame(maxWidth: .infinity)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 6))

                            Text(name)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.white)
                                .shadow(radius: 2)
                                .padding(5)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }

            Divider()

            HStack(spacing: 6) {
                TextField("Paste image URL...", text: $customCoverUrlInput)
                    .textFieldStyle(.plain)
                    .font(.caption)
                    .padding(6)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    )
                    .onSubmit {
                        let trimmed = customCoverUrlInput.trimmingCharacters(in: .whitespaces)
                        if !trimmed.isEmpty {
                            store.updatePageCover(pageId: currentPage.id, newCoverUrl: trimmed)
                            customCoverUrlInput = ""
                            isCoverPickerOpen = false
                        }
                    }

                Button("Set") {
                    let trimmed = customCoverUrlInput.trimmingCharacters(in: .whitespaces)
                    if !trimmed.isEmpty {
                        store.updatePageCover(pageId: currentPage.id, newCoverUrl: trimmed)
                        customCoverUrlInput = ""
                        isCoverPickerOpen = false
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Button("Random") {
                    let allOptions = PresetGradientCover.allCases.map(\.rawValue) + unsplashPhotos.map(\.1)
                    if let rand = allOptions.randomElement() {
                        store.updatePageCover(pageId: currentPage.id, newCoverUrl: rand)
                        isCoverPickerOpen = false
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(14)
        .frame(width: 340)
    }

    // MARK: - Floating Selection Toolbar

    private var floatingSelectionToolbar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 7, height: 7)
                Text("\(selectedBlockIds.count) selected")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 4)

            Divider()
                .frame(height: 14)

            Menu {
                Section("Turn into") {
                    Button("Text") { blockActionTrigger = .transformSelected(.paragraph) }
                    Button("Heading 1") { blockActionTrigger = .transformSelected(.heading(level: 1)) }
                    Button("Heading 2") { blockActionTrigger = .transformSelected(.heading(level: 2)) }
                    Button("Heading 3") { blockActionTrigger = .transformSelected(.heading(level: 3)) }
                    Button("To-do List") { blockActionTrigger = .transformSelected(.todo(checked: false)) }
                    Button("Bulleted List") { blockActionTrigger = .transformSelected(.bullet) }
                    Button("Numbered List") { blockActionTrigger = .transformSelected(.numbered(index: 1)) }
                    Button("Quote") { blockActionTrigger = .transformSelected(.quote) }
                    Button("Code Block") { blockActionTrigger = .transformSelected(.code(lang: "rust")) }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 11, weight: .medium))
                    Text("Turn into")
                        .font(.system(size: 12, weight: .medium))
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 8))
                }
                .foregroundStyle(.primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.primary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)

            Button(action: {
                blockActionTrigger = .duplicateSelected
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "plus.square.on.square")
                        .font(.system(size: 11, weight: .medium))
                    Text("Duplicate")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(.primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.primary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)

            Button(role: .destructive, action: {
                blockActionTrigger = .deleteSelected
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "trash")
                        .font(.system(size: 11, weight: .medium))
                    Text("Delete")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(.red)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.red.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)

            Divider()
                .frame(height: 14)

            // Multi-block formatting buttons
            HStack(spacing: 2) {
                toolbarButton(icon: "bold", help: "Bold (⌘B)") {
                    blockActionTrigger = .formatActiveBlock("**")
                }
                toolbarButton(icon: "italic", help: "Italic (⌘I)") {
                    blockActionTrigger = .formatActiveBlock("*")
                }
                toolbarButton(icon: "strikethrough", help: "Strikethrough") {
                    blockActionTrigger = .formatActiveBlock("~~")
                }
                toolbarButton(icon: "curlybraces", help: "Inline Code") {
                    blockActionTrigger = .formatActiveBlock("`")
                }
            }

            Divider()
                .frame(height: 14)

            Button(action: {
                selectedBlockIds.removeAll()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .padding(5)
                    .background(Color.primary.opacity(0.06))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(.ultraThickMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.18), radius: 14, y: 5)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }
}
