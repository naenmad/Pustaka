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
        return [Color.appPrimary.opacity(0.8), Color.purple.opacity(0.8)]
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
    var fontSize: CGFloat = 34.0
    var onCommit: () -> Void
    var onTextChanged: (String) -> Void
    var onBeginEditing: (() -> Void)? = nil

    func makeNSView(context: Context) -> NSTextField {
        let tf = FocusableTitleTextField()
        tf.isBordered = false
        tf.drawsBackground = false
        tf.focusRingType = .none
        tf.font = NSFont.systemFont(ofSize: fontSize, weight: .bold)
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
        if nsView.font?.pointSize != fontSize {
            nsView.font = NSFont.systemFont(ofSize: fontSize, weight: .bold)
        }
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

    @AppStorage("appPrimaryColorHex") private var appPrimaryColorHex: String = "#007AFF"
    @AppStorage("editorFontSize") private var editorFontSize: Double = 15.0

    private var primaryColor: Color {
        Color(hex: appPrimaryColorHex)
    }

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
    @State private var metSearchText: String = ""
    @State private var metSearchResults: [MetArtwork] = []
    @State private var isMetSearching: Bool = false
    @State private var coverPickerTab: Int = 0
    @State private var isRepositioningCover: Bool = false
    @State private var currentCoverOffsetY: Double = 0.5
    @State private var currentCoverOffsetX: Double = 0.5
    @State private var currentCoverScale: Double = 1.0
    @State private var initialDragOffsetY: Double = 0.5
    @State private var initialDragOffsetX: Double = 0.5

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
            documentCanvasBody

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
        .onAppear {
            self.titleBuffer = currentPage.title
            self.currentCoverOffsetY = currentPage.coverOffsetY
            self.currentCoverOffsetX = currentPage.coverOffsetX
            self.currentCoverScale = currentPage.coverScale
        }
        .onChange(of: page.id) { _, _ in
            self.titleBuffer = currentPage.title
            self.currentCoverOffsetY = currentPage.coverOffsetY
            self.currentCoverOffsetX = currentPage.coverOffsetX
            self.currentCoverScale = currentPage.coverScale
            self.isRepositioningCover = false
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenCoverPicker"))) { _ in
            self.isCoverPickerOpen = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenIconPicker"))) { _ in
            self.isIconPickerOpen = true
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
                    Button("Info Callout") { blockActionTrigger = .insertBlock(.callout(icon: "info.circle.fill", theme: .blue)) }
                    Button("Warning Callout") { blockActionTrigger = .insertBlock(.callout(icon: "exclamationmark.triangle.fill", theme: .red)) }
                    Button("Tip Callout") { blockActionTrigger = .insertBlock(.callout(icon: "checkmark.circle.fill", theme: .green)) }
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
    private func toolbarButton(icon: String, isActive: Bool = false, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: isActive ? .bold : .medium))
                .foregroundStyle(isActive ? primaryColor : Color.secondary)
                .frame(width: 26, height: 26)
                .background(isActive ? primaryColor.opacity(0.22) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isActive ? primaryColor.opacity(0.4) : Color.clear, lineWidth: 1)
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

                    // Clickable empty canvas space to immediately start writing at the bottom
                    Color.clear
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 180)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            blockActionTrigger = .insertBlock(.paragraph)
                        }

                    Spacer(minLength: 100)
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(.horizontal, 16)
                .padding(.top, currentPage.coverUrl.isEmpty ? 24 : 14)
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Cover Banner View (Supports Drag, Zoom & Crop Adjustment)

    private var pageCoverBannerView: some View {
        ZStack(alignment: .bottomTrailing) {
            GeometryReader { geo in
                let scale = isRepositioningCover ? currentCoverScale : currentPage.coverScale
                let offsetY = isRepositioningCover ? currentCoverOffsetY : currentPage.coverOffsetY
                let offsetX = isRepositioningCover ? currentCoverOffsetX : currentPage.coverOffsetX

                coverImageContent
                    .scaleEffect(scale)
                    .offset(
                        x: (0.5 - offsetX) * (geo.size.width * (scale - 1.0) + 160),
                        y: (0.5 - offsetY) * (230 * scale)
                    )
                    .frame(width: geo.size.width, height: 350)
            }
            .frame(height: 350)
            .clipped()
            .contentShape(Rectangle())
            .gesture(
                isRepositioningCover ?
                DragGesture()
                    .onChanged { value in
                        let deltaY = -Double(value.translation.height) / (200.0 * currentCoverScale)
                        let deltaX = -Double(value.translation.width) / (300.0 * currentCoverScale)
                        currentCoverOffsetY = max(0.0, min(1.0, initialDragOffsetY + deltaY))
                        currentCoverOffsetX = max(0.0, min(1.0, initialDragOffsetX + deltaX))
                    }
                    .onEnded { _ in
                        initialDragOffsetY = currentCoverOffsetY
                        initialDragOffsetX = currentCoverOffsetX
                    }
                : nil
            )

            // Smooth Tall Gradient Blend to Document Canvas Background (0% opacity at top to 100% solid at bottom)
            LinearGradient(
                stops: [
                    .init(color: Color(nsColor: .windowBackgroundColor).opacity(0.0), location: 0.0),
                    .init(color: Color(nsColor: .windowBackgroundColor).opacity(0.02), location: 0.06),
                    .init(color: Color(nsColor: .windowBackgroundColor).opacity(0.07), location: 0.20),
                    .init(color: Color(nsColor: .windowBackgroundColor).opacity(0.16), location: 0.34),
                    .init(color: Color(nsColor: .windowBackgroundColor).opacity(0.30), location: 0.48),
                    .init(color: Color(nsColor: .windowBackgroundColor).opacity(0.48), location: 0.62),
                    .init(color: Color(nsColor: .windowBackgroundColor).opacity(0.68), location: 0.74),
                    .init(color: Color(nsColor: .windowBackgroundColor).opacity(0.86), location: 0.85),
                    .init(color: Color(nsColor: .windowBackgroundColor).opacity(0.97), location: 0.93),
                    .init(color: Color(nsColor: .windowBackgroundColor), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 350)
            .allowsHitTesting(false)
            .opacity(isRepositioningCover ? 0.20 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isRepositioningCover)

            // Crop Guidelines Grid (Visible when adjusting)
            if isRepositioningCover {
                cropGuidelinesOverlay
            }

            // Adjustment & Zoom Control Bar
            if isRepositioningCover {
                coverAdjustmentToolbar
            }

            // Normal Hover Action Buttons (Change Cover, Adjust, Remove)
            if !isRepositioningCover {
                coverNormalActionButtons
            }
        }
        .contentShape(Rectangle())
        .onHover { isCoverHovered = $0 }
    }

    private var cropGuidelinesOverlay: some View {
        GeometryReader { geo in
            Path { path in
                let w = geo.size.width
                let h = geo.size.height
                // Vertical grid lines (rule of thirds)
                path.move(to: CGPoint(x: w / 3, y: 0))
                path.addLine(to: CGPoint(x: w / 3, y: h))
                path.move(to: CGPoint(x: 2 * w / 3, y: 0))
                path.addLine(to: CGPoint(x: 2 * w / 3, y: h))
                // Horizontal grid lines
                path.move(to: CGPoint(x: 0, y: h / 3))
                path.addLine(to: CGPoint(x: w, y: h / 3))
                path.move(to: CGPoint(x: 0, y: 2 * h / 3))
                path.addLine(to: CGPoint(x: w, y: 2 * h / 3))
            }
            .stroke(Color.white.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
        }
        .allowsHitTesting(false)
        .transition(.opacity)
    }

    private var coverAdjustmentToolbar: some View {
        VStack {
            HStack(spacing: 12) {
                HStack(spacing: 5) {
                    Image(systemName: "crop")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Adjust Cover")
                        .font(.system(size: 11.5, weight: .semibold))
                }
                .foregroundStyle(.white)

                Divider()
                    .frame(height: 12)
                    .opacity(0.3)

                // Zoom control
                HStack(spacing: 6) {
                    Image(systemName: "minus.magnifyingglass")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.8))

                    Slider(value: $currentCoverScale, in: 1.0...3.5, step: 0.05)
                        .frame(width: 90)
                        .controlSize(.mini)

                    Image(systemName: "plus.magnifyingglass")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.8))

                    Text("\(String(format: "%.1f", currentCoverScale))x")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                        .frame(width: 30)
                }

                Divider()
                    .frame(height: 12)
                    .opacity(0.3)

                // Reset button
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        currentCoverOffsetX = 0.5
                        currentCoverOffsetY = 0.5
                        currentCoverScale = 1.0
                        initialDragOffsetX = 0.5
                        initialDragOffsetY = 0.5
                    }
                }) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 10))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .help("Reset to center & 1.0x")

                Spacer()

                Button("Cancel") {
                    currentCoverOffsetX = currentPage.coverOffsetX
                    currentCoverOffsetY = currentPage.coverOffsetY
                    currentCoverScale = currentPage.coverScale
                    isRepositioningCover = false
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("Done") {
                    store.updatePageCoverAdjustment(
                        pageId: currentPage.id,
                        offsetX: currentCoverOffsetX,
                        offsetY: currentCoverOffsetY,
                        scale: currentCoverScale
                    )
                    isRepositioningCover = false
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .shadow(color: Color.black.opacity(0.28), radius: 8, y: 3)
            .padding(.top, 14)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .transition(.opacity)
    }

    private var coverNormalActionButtons: some View {
        HStack(spacing: 6) {
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

            // Adjust Button (Zoom, Pan, Crop)
            Button(action: {
                currentCoverOffsetY = currentPage.coverOffsetY
                currentCoverOffsetX = currentPage.coverOffsetX
                currentCoverScale = currentPage.coverScale
                initialDragOffsetY = currentPage.coverOffsetY
                initialDragOffsetX = currentPage.coverOffsetX
                withAnimation(.easeInOut(duration: 0.2)) {
                    isRepositioningCover = true
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "crop")
                        .font(.caption)
                    Text("Adjust")
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
            .help("Adjust position, zoom, and crop")

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

    // MARK: - Cover Image Content Renderer

    @ViewBuilder
    private var coverImageContent: some View {
        if currentPage.coverUrl.hasPrefix("gradient:") {
            LinearGradient(
                colors: PresetGradientCover.colors(for: currentPage.coverUrl),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else if let localPath = store.resolveVaultImagePath(currentPage.coverUrl),
                  let nsImg = NSImage(contentsOfFile: localPath) {
            Image(nsImage: nsImg)
                .resizable()
                .scaledToFill()
        } else if currentPage.coverUrl.hasPrefix("/") || currentPage.coverUrl.hasPrefix("file://") {
            let cleanPath = currentPage.coverUrl.replacingOccurrences(of: "file://", with: "")
            if let nsImg = NSImage(contentsOfFile: cleanPath) {
                Image(nsImage: nsImg)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.secondary.opacity(0.15)
            }
        } else {
            AsyncImage(url: URL(string: currentPage.coverUrl)) { phase in
                switch phase {
                case .empty:
                    LinearGradient(
                        colors: [primaryColor.opacity(0.3), Color.purple.opacity(0.3)],
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

    // MARK: - Notion Page Header

    private var notionPageHeaderView: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Breadcrumbs for nested Subpages
            if let parent = store.page(id: currentPage.parentPageId) {
                HStack(spacing: 5) {
                    Button(action: {
                        store.selectPage(id: parent.id)
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.secondary)
                            DynamicIconView(icon: parent.icon, size: 10, defaultSymbol: "doc.text")
                                .foregroundStyle(primaryColor)
                            Text(parent.title.isEmpty ? "Untitled" : parent.title)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)

                    Text("/")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    HStack(spacing: 4) {
                        DynamicIconView(icon: currentPage.icon, size: 10, defaultSymbol: "doc.text")
                            .foregroundStyle(primaryColor)
                        Text(currentPage.title.isEmpty ? "Untitled" : currentPage.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.primary)
                    }
                }
                .padding(.bottom, 2)
            }

            HStack(spacing: 10) {
                if currentPage.icon.isEmpty {
                    Button(action: {
                        isIconPickerOpen = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                                .font(.caption)
                            Text("Add icon")
                                .font(.caption.weight(.medium))
                        }
                        .foregroundStyle(primaryColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(primaryColor.opacity(0.08))
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
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(primaryColor.opacity(0.12))
                            .frame(width: 52, height: 52)
                        DynamicIconView(icon: currentPage.icon, size: 30, weight: .medium, defaultSymbol: "doc.text")
                            .foregroundStyle(primaryColor)
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Click to change or remove icon")
            }

            TitleEditorField(
                text: $titleBuffer,
                placeholder: "Untitled",
                fontSize: round(34.0 * (CGFloat(editorFontSize) / 15.0)),
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
            NativeIconPickerPopover(
                currentIcon: currentPage.icon,
                onIconSelected: { icon in
                    store.updatePageIcon(pageId: currentPage.id, newIcon: icon)
                    isIconPickerOpen = false
                },
                onRemove: {
                    store.updatePageIcon(pageId: currentPage.id, newIcon: "")
                    isIconPickerOpen = false
                }
            )
        }
        .popover(isPresented: $isCoverPickerOpen) {
            coverPickerPopover
        }
    }

    // MARK: - Cover Picker Popover (Generous Size, Beautiful Cards, No Cropping)

    private var coverPickerPopover: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Cover Image")
                        .font(.headline.weight(.semibold))
                    Text("Select a museum masterpiece, vibrant gradient, or upload a custom image.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if !currentPage.coverUrl.isEmpty {
                    Button(action: {
                        store.updatePageCover(pageId: currentPage.id, newCoverUrl: "")
                        isCoverPickerOpen = false
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "trash")
                            Text("Remove Cover")
                        }
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Tabs
            Picker("", selection: $coverPickerTab) {
                Text("The Met Masterpieces").tag(0)
                Text("Gradients").tag(1)
                Text("Upload & URL").tag(2)
            }
            .pickerStyle(.segmented)

            // Content
            if coverPickerTab == 0 {
                // The Met Collection Masterpieces
                VStack(alignment: .leading, spacing: 10) {
                    // Search Bar
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)

                        TextField("Search The Met Collection (e.g. Monet, Japan, Landscape, Floral)...", text: $metSearchText)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12))
                            .onSubmit {
                                searchTheMet()
                            }

                        if isMetSearching {
                            ProgressView()
                                .controlSize(.small)
                        } else if !metSearchText.isEmpty {
                            Button(action: {
                                metSearchText = ""
                                metSearchResults = []
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }

                        Button("Search") {
                            searchTheMet()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                    .padding(8)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
                    )

                    let artworksToShow = metSearchResults.isEmpty ? TheMetService.shared.curatedArtworks : metSearchResults

                    ScrollView(.vertical, showsIndicators: true) {
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                            ForEach(artworksToShow) { art in
                                Button(action: {
                                    store.updatePageCover(pageId: currentPage.id, newCoverUrl: art.imageUrl)
                                    isCoverPickerOpen = false
                                }) {
                                    ZStack(alignment: .bottomLeading) {
                                        AsyncImage(url: URL(string: art.imageUrl)) { phase in
                                            if let img = phase.image {
                                                img.resizable().scaledToFill()
                                            } else {
                                                Color.secondary.opacity(0.12)
                                            }
                                        }
                                        .frame(height: 96)
                                        .frame(maxWidth: .infinity)
                                        .clipped()
                                        .clipShape(RoundedRectangle(cornerRadius: 8))

                                        // Dark gradient for crisp text contrast
                                        LinearGradient(
                                            colors: [Color.clear, Color.black.opacity(0.85)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: 8))

                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(art.title)
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundStyle(.white)
                                                .lineLimit(1)

                                            HStack(spacing: 4) {
                                                Text(art.artist)
                                                    .font(.system(size: 9.5))
                                                    .foregroundStyle(.white.opacity(0.88))
                                                    .lineLimit(1)
                                                if !art.year.isEmpty {
                                                    Text("•")
                                                        .font(.system(size: 7))
                                                        .foregroundStyle(.white.opacity(0.5))
                                                    Text(art.year)
                                                        .font(.system(size: 8.5))
                                                        .foregroundStyle(.white.opacity(0.75))
                                                        .lineLimit(1)
                                                }
                                            }
                                        }
                                        .padding(7)
                                    }
                                    .contentShape(Rectangle())
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(currentPage.coverUrl == art.imageUrl ? primaryColor : Color.clear, lineWidth: 2)
                                    )
                                }
                                .buttonStyle(.plain)
                                .help("\(art.title) by \(art.artist) (\(art.year))")
                            }
                        }
                        .padding(.vertical, 2)
                        .padding(.trailing, 4)
                    }
                    .frame(height: 290)
                }
            } else if coverPickerTab == 1 {
                // Vibrant Gradients
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
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
                                    .frame(height: 70)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))

                                    Text(preset.title)
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .padding(8)
                                }
                                .contentShape(Rectangle())
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(currentPage.coverUrl == preset.rawValue ? Color.white : Color.clear, lineWidth: 2)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(height: 290)
            } else {
                // Upload & Custom URL
                VStack(alignment: .leading, spacing: 16) {
                    // Local Upload Card
                    Button(action: {
                        if let localAsset = store.importLocalImageToVault() {
                            store.updatePageCover(pageId: currentPage.id, newCoverUrl: localAsset)
                            isCoverPickerOpen = false
                        }
                    }) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(primaryColor.opacity(0.12))
                                    .frame(width: 44, height: 44)
                                Image(systemName: "arrow.up.doc.fill")
                                    .font(.system(size: 18))
                                    .foregroundStyle(primaryColor)
                            }

                            VStack(alignment: .leading, spacing: 3) {
                                Text("Upload Image from Mac")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.primary)
                                Text("Select PNG, JPG, WebP, or GIF from your Mac. Image will be copied into your vault.")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(14)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)

                    Divider()

                    // URL Input Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Paste Image URL")
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(.secondary)

                        HStack(spacing: 8) {
                            TextField("https://images.example.com/cover.jpg", text: $customCoverUrlInput)
                                .textFieldStyle(.plain)
                                .font(.system(size: 12))
                                .padding(8)
                                .background(Color(nsColor: .controlBackgroundColor))
                                .clipShape(RoundedRectangle(cornerRadius: 7))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 7)
                                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                                )
                                .onSubmit {
                                    applyCustomCoverUrl()
                                }

                            Button("Set Cover") {
                                applyCustomCoverUrl()
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.regular)
                        }
                    }

                    Spacer()
                }
                .padding(.top, 4)
                .frame(height: 290)
            }
        }
        .padding(18)
        .frame(width: 540, height: 440)
    }

    private func searchTheMet() {
        let trimmed = metSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            metSearchResults = []
            return
        }
        isMetSearching = true
        Task {
            let results = await TheMetService.shared.search(query: trimmed)
            await MainActor.run {
                self.metSearchResults = results
                self.isMetSearching = false
            }
        }
    }

    private func applyCustomCoverUrl() {
        let trimmed = customCoverUrlInput.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            store.updatePageCover(pageId: currentPage.id, newCoverUrl: trimmed)
            customCoverUrlInput = ""
            isCoverPickerOpen = false
        }
    }

    // MARK: - Floating Selection Toolbar

    private var floatingSelectionToolbar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                Circle()
                    .fill(primaryColor)
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
