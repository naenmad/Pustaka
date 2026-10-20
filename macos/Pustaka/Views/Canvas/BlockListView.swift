import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - Live Inline Markdown Styler Engine (True WYSIWYG - Zero Delimiters on Screen)

struct MarkdownStyleFlags: OptionSet {
    let rawValue: Int
    static let bold      = MarkdownStyleFlags(rawValue: 1 << 0)
    static let italic    = MarkdownStyleFlags(rawValue: 1 << 1)
    static let strike    = MarkdownStyleFlags(rawValue: 1 << 2)
    static let highlight = MarkdownStyleFlags(rawValue: 1 << 3)
    static let code      = MarkdownStyleFlags(rawValue: 1 << 4)
}

enum MarkdownStyler {
    /// Converts a Markdown string into an NSAttributedString by recursively stripping delimiters (***...***, **...**, ~~...~~, etc.)
    /// and applying font traits (Bold, Italic) and styles (Strike, Highlight, Code) so no formatting symbols ever appear on screen.
    static func markdownToAttributedString(
        _ md: String,
        baseFont: NSFont,
        baseColor: NSColor = .labelColor
    ) -> NSAttributedString {
        guard !md.isEmpty else {
            return NSAttributedString(string: "", attributes: [.font: baseFont, .foregroundColor: baseColor])
        }

        let result = NSMutableAttributedString()
        parseNode(md, currentFlags: [], baseFont: baseFont, baseColor: baseColor, into: result)
        return result
    }

    private static func parseNode(
        _ text: String,
        currentFlags: MarkdownStyleFlags,
        baseFont: NSFont,
        baseColor: NSColor,
        into output: NSMutableAttributedString
    ) {
        guard !text.isEmpty else { return }

        // Matches inline formatting blocks:
        // Group 2: ***...*** (Bold+Italic)
        // Group 4: **...** (Bold)
        // Group 6: *...* (Italic)
        // Group 8: _..._ (Italic)
        // Group 10: ~~...~~ (Strikethrough)
        // Group 12: `...` (Inline Code)
        // Group 14: ==...== (Highlight)
        let pattern = #"(\*\*\*([^\*]+)\*\*\*)|(\*\*([^\*]+)\*\*)|((?<!\*)\*([^\*]+)\*(?!\*))|((?<!\w)_([^_]+)_(?!\w))|(~~([^~]+)~~)|(`([^`]+)`)|(==([^=]+)==)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            appendLeaf(text, flags: currentFlags, baseFont: baseFont, baseColor: baseColor, into: output)
            return
        }

        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
        if matches.isEmpty {
            appendLeaf(text, flags: currentFlags, baseFont: baseFont, baseColor: baseColor, into: output)
            return
        }

        var lastIndex = 0
        for match in matches {
            if match.range.location > lastIndex {
                let plain = nsText.substring(with: NSRange(location: lastIndex, length: match.range.location - lastIndex))
                appendLeaf(plain, flags: currentFlags, baseFont: baseFont, baseColor: baseColor, into: output)
            }

            if let r = Range(match.range(at: 2), in: text) {
                // ***text***
                let inner = String(text[r])
                parseNode(inner, currentFlags: currentFlags.union([.bold, .italic]), baseFont: baseFont, baseColor: baseColor, into: output)
            } else if let r = Range(match.range(at: 4), in: text) {
                // **text**
                let inner = String(text[r])
                parseNode(inner, currentFlags: currentFlags.union([.bold]), baseFont: baseFont, baseColor: baseColor, into: output)
            } else if let r = Range(match.range(at: 6), in: text) ?? Range(match.range(at: 8), in: text) {
                // *text* or _text_
                let inner = String(text[r])
                parseNode(inner, currentFlags: currentFlags.union([.italic]), baseFont: baseFont, baseColor: baseColor, into: output)
            } else if let r = Range(match.range(at: 10), in: text) {
                // ~~text~~
                let inner = String(text[r])
                parseNode(inner, currentFlags: currentFlags.union([.strike]), baseFont: baseFont, baseColor: baseColor, into: output)
            } else if let r = Range(match.range(at: 12), in: text) {
                // `text` (code does not parse markdown inside)
                let inner = String(text[r])
                appendLeaf(inner, flags: currentFlags.union([.code]), baseFont: baseFont, baseColor: baseColor, into: output)
            } else if let r = Range(match.range(at: 14), in: text) {
                // ==text==
                let inner = String(text[r])
                parseNode(inner, currentFlags: currentFlags.union([.highlight]), baseFont: baseFont, baseColor: baseColor, into: output)
            }

            lastIndex = match.range.location + match.range.length
        }

        if lastIndex < nsText.length {
            let plain = nsText.substring(with: NSRange(location: lastIndex, length: nsText.length - lastIndex))
            appendLeaf(plain, flags: currentFlags, baseFont: baseFont, baseColor: baseColor, into: output)
        }
    }

    private static func appendLeaf(
        _ str: String,
        flags: MarkdownStyleFlags,
        baseFont: NSFont,
        baseColor: NSColor,
        into output: NSMutableAttributedString
    ) {
        guard !str.isEmpty else { return }

        var font = baseFont
        if flags.contains(.code) {
            font = NSFont.monospacedSystemFont(ofSize: baseFont.pointSize * 0.9, weight: .regular)
        } else {
            let isBold = flags.contains(.bold)
            let isItalic = flags.contains(.italic)
            if isBold && isItalic {
                var bi = NSFontManager.shared.convert(baseFont, toHaveTrait: .boldFontMask)
                bi = NSFontManager.shared.convert(bi, toHaveTrait: .italicFontMask)
                font = bi
            } else if isBold {
                font = NSFontManager.shared.convert(baseFont, toHaveTrait: .boldFontMask)
            } else if isItalic {
                font = NSFontManager.shared.convert(baseFont, toHaveTrait: .italicFontMask)
            }
        }

        var attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: baseColor
        ]

        if flags.contains(.strike) {
            attrs[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
        }

        if flags.contains(.highlight) {
            attrs[.backgroundColor] = NSColor.systemYellow.withAlphaComponent(0.28)
        }

        if flags.contains(.code) {
            attrs[.foregroundColor] = NSColor.systemRed
            attrs[.backgroundColor] = NSColor.quaternaryLabelColor
        }

        output.append(NSAttributedString(string: str, attributes: attrs))
    }

    /// Converts an NSAttributedString back into standard Markdown for disk persistence
    static func attributedStringToMarkdown(_ attr: NSAttributedString) -> String {
        var md = ""
        let string = attr.string
        guard !string.isEmpty else { return "" }

        attr.enumerateAttributes(in: NSRange(location: 0, length: (string as NSString).length), options: []) { attrs, range, _ in
            let substring = (string as NSString).substring(with: range)
            var formatted = substring

            let font = attrs[.font] as? NSFont
            let traits = font.map { NSFontManager.shared.traits(of: $0) } ?? []
            let isBold = traits.contains(.boldFontMask)
            let isItalic = traits.contains(.italicFontMask)
            let isStrike = (attrs[.strikethroughStyle] as? Int) != nil && (attrs[.strikethroughStyle] as? Int) != 0
            let isCode = font?.isFixedPitch ?? false || (attrs[.backgroundColor] as? NSColor) == NSColor.quaternaryLabelColor
            let isHighlight = (attrs[.backgroundColor] as? NSColor)?.alphaComponent ?? 0.0 > 0.25 && !isCode

            if isCode {
                formatted = "`" + formatted + "`"
            } else {
                if isBold && isItalic {
                    formatted = "***" + formatted + "***"
                } else if isBold {
                    formatted = "**" + formatted + "**"
                } else if isItalic {
                    formatted = "*" + formatted + "*"
                }
                if isStrike { formatted = "~~" + formatted + "~~" }
                if isHighlight { formatted = "==" + formatted + "==" }
            }
            md += formatted
        }
        return md
    }
}

// MARK: - Auto-Growing Word-Wrapping Block Editor Text View (Zero Horizontal Scrolling)

final class BlockEditorTextView: NSTextView {
    var placeholderText: String = ""
    var onCommit: (() -> Void)?
    var onDeleteEmpty: (() -> Void)?
    var onSlashCommit: (() -> Bool)?
    var onEscape: (() -> Bool)?
    var onSelectAllBlocks: (() -> Void)?
    var onFocus: (() -> Void)?
    var onFormattingStateChanged: ((EditorFormattingState) -> Void)?
    var onHeightChange: ((CGFloat) -> Void)?

    private var lastReportedHeight: CGFloat = 0

    override var acceptsFirstResponder: Bool { true }

    override func becomeFirstResponder() -> Bool {
        let textLenBefore = (string as NSString).length
        let ok = super.becomeFirstResponder()
        if ok {
            if textLenBefore > 0 {
                let sel = selectedRange()
                if sel.location == 0 && sel.length == 0 {
                    setSelectedRange(NSRange(location: textLenBefore, length: 0))
                }
            }
            onFocus?()
            updateFormattingState()
            recalculateHeight()
            needsDisplay = true
        }
        return ok
    }

    override func resignFirstResponder() -> Bool {
        let ok = super.resignFirstResponder()
        needsDisplay = true
        return ok
    }

    override func mouseDown(with event: NSEvent) {
        onFocus?()
        super.mouseDown(with: event)
        updateFormattingState()
        recalculateHeight()
    }

    override func setFrameSize(_ newSize: NSSize) {
        let oldW = frame.width
        super.setFrameSize(newSize)
        if abs(newSize.width - oldW) > 1 {
            recalculateHeight()
        }
    }

    override func didChangeText() {
        super.didChangeText()
        recalculateHeight()
        invalidateIntrinsicContentSize()
    }

    override var intrinsicContentSize: NSSize {
        guard let lm = layoutManager, let tc = textContainer else { return super.intrinsicContentSize }
        lm.ensureLayout(for: tc)
        let used = lm.usedRect(for: tc)
        let minH = (font?.pointSize ?? 15) * 1.35
        let h = ceil(max(used.height + textContainerInset.height * 2, minH))
        return NSSize(width: NSView.noIntrinsicMetric, height: h)
    }

    func recalculateHeight() {
        guard let lm = layoutManager, let tc = textContainer else { return }
        lm.ensureLayout(for: tc)
        let used = lm.usedRect(for: tc)
        let minH = (font?.pointSize ?? 15) * 1.35
        let h = ceil(max(used.height + textContainerInset.height * 2, minH))
        if abs(h - lastReportedHeight) > 1 {
            lastReportedHeight = h
            DispatchQueue.main.async { [weak self] in
                self?.onHeightChange?(h)
            }
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        if string.isEmpty && !placeholderText.isEmpty {
            let padding = textContainer?.lineFragmentPadding ?? 0
            let rect = NSRect(
                x: textContainerInset.width + padding,
                y: textContainerInset.height,
                width: bounds.width - (textContainerInset.width + padding) * 2,
                height: bounds.height
            )
            let attrs: [NSAttributedString.Key: Any] = [
                .font: self.font ?? NSFont.systemFont(ofSize: 15),
                .foregroundColor: NSColor.placeholderTextColor
            ]
            (placeholderText as NSString).draw(in: rect, withAttributes: attrs)
        }
    }

    override func keyDown(with event: NSEvent) {
        // Return / Enter Key (keyCode 36)
        if event.keyCode == 36 {
            if event.modifierFlags.contains(.shift) {
                // Shift+Enter: soft newline inside the same block
                super.keyDown(with: event)
                recalculateHeight()
                invalidateIntrinsicContentSize()
                return
            }
            if let slashHandler = onSlashCommit, slashHandler() {
                return
            }
            onCommit?()
            return
        }

        // Escape Key (keyCode 53)
        if event.keyCode == 53 {
            if let escHandler = onEscape, escHandler() {
                return
            }
        }

        // Backspace / Delete Key (keyCode 51)
        if event.keyCode == 51 {
            if string.isEmpty {
                onDeleteEmpty?()
                return
            }
        }

        // Cmd+A inside text: if all text already selected, trigger multi-block selection
        if event.keyCode == 0 && event.modifierFlags.contains(.command) { // 'a' key
            let selLen = selectedRange().length
            let totalLen = (string as NSString).length
            if selLen == totalLen && totalLen > 0 {
                onSelectAllBlocks?()
                return
            }
        }

        super.keyDown(with: event)
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let pboard = sender.draggingPasteboard
        if let types = pboard.types, types.contains(NSPasteboard.PasteboardType("com.pustaka.block-drag")) {
            return []
        }
        if let str = pboard.string(forType: .string), str.hasPrefix("blk_") {
            return []
        }
        return super.draggingEntered(sender)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pboard = sender.draggingPasteboard
        if let types = pboard.types, types.contains(NSPasteboard.PasteboardType("com.pustaka.block-drag")) {
            return false
        }
        if let str = pboard.string(forType: .string), str.hasPrefix("blk_") {
            return false
        }
        return super.performDragOperation(sender)
    }

    func updateFormattingState() {
        guard let storage = textStorage else { return }
        let sel = selectedRange()
        var traits: NSFontTraitMask = []
        var hasStrike = false
        var hasCode = false

        if sel.length > 0 && sel.location < storage.length {
            let attrs = storage.attributes(at: sel.location, effectiveRange: nil)
            if let f = attrs[.font] as? NSFont {
                traits = NSFontManager.shared.traits(of: f)
                if f.isFixedPitch { hasCode = true }
            }
            if let s = attrs[.strikethroughStyle] as? Int, s != 0 {
                hasStrike = true
            }
            if (attrs[.backgroundColor] as? NSColor) == NSColor.quaternaryLabelColor {
                hasCode = true
            }
        } else {
            let attrs = typingAttributes
            if let f = attrs[.font] as? NSFont {
                traits = NSFontManager.shared.traits(of: f)
                if f.isFixedPitch { hasCode = true }
            }
            if let s = attrs[.strikethroughStyle] as? Int, s != 0 {
                hasStrike = true
            }
            if (attrs[.backgroundColor] as? NSColor) == NSColor.quaternaryLabelColor {
                hasCode = true
            }
        }

        let state = EditorFormattingState(
            isBold: traits.contains(.boldFontMask),
            isItalic: traits.contains(.italicFontMask),
            isStrike: hasStrike,
            isCode: hasCode
        )
        onFormattingStateChanged?(state)
    }
}

// MARK: - Native AppKit Block Editor Field (Multiline Word-Wrapping, True WYSIWYG, Real-time Formatting)

struct BlockEditorField: NSViewRepresentable {
    @Binding var text: String
    @Binding var dynamicHeight: CGFloat
    var placeholder: String
    var font: NSFont
    var textColor: NSColor = .labelColor
    var isFocused: Bool
    var onCommit: () -> Void
    var onDeleteEmpty: () -> Void
    var onSlashCommit: (() -> Bool)? = nil
    var onEscape: (() -> Bool)? = nil
    var onTextChanged: ((String) -> Void)? = nil
    var onFocus: (() -> Void)? = nil
    var onSelectAllBlocks: (() -> Void)? = nil
    var onFormattingStateChanged: ((EditorFormattingState) -> Void)? = nil

    func makeNSView(context: Context) -> BlockEditorTextView {
        let tv = BlockEditorTextView()
        tv.isRichText = true
        tv.importsGraphics = false
        tv.allowsUndo = true
        tv.isEditable = true
        tv.isSelectable = true
        tv.drawsBackground = false
        tv.focusRingType = .none
        tv.font = font
        tv.textColor = textColor
        tv.placeholderText = placeholder
        tv.isHorizontallyResizable = false
        tv.isVerticallyResizable = true
        tv.textContainer?.widthTracksTextView = true
        tv.textContainer?.lineFragmentPadding = 0
        tv.textContainerInset = NSSize(width: 0, height: 2)
        tv.delegate = context.coordinator

        tv.onCommit = onCommit
        tv.onDeleteEmpty = onDeleteEmpty
        tv.onSlashCommit = onSlashCommit
        tv.onEscape = onEscape
        tv.onSelectAllBlocks = onSelectAllBlocks
        tv.onFocus = onFocus
        tv.onFormattingStateChanged = onFormattingStateChanged
        tv.onHeightChange = { newH in
            if abs(dynamicHeight - newH) > 1 {
                dynamicHeight = newH
            }
        }

        let styled = MarkdownStyler.markdownToAttributedString(text, baseFont: font, baseColor: textColor)
        tv.textStorage?.setAttributedString(styled)
        tv.recalculateHeight()

        if isFocused {
            context.coordinator.didFocusOnce = true
            let focusBlock = {
                if let window = tv.window, window.firstResponder != tv {
                    window.makeFirstResponder(tv)
                }
                let len = (tv.string as NSString).length
                tv.setSelectedRange(NSRange(location: len, length: 0))
            }
            if tv.window != nil {
                focusBlock()
            } else {
                DispatchQueue.main.async {
                    focusBlock()
                }
            }
        }

        return tv
    }

    func updateNSView(_ nsView: BlockEditorTextView, context: Context) {
        nsView.placeholderText = placeholder
        nsView.font = font
        nsView.textColor = textColor
        nsView.onCommit = onCommit
        nsView.onDeleteEmpty = onDeleteEmpty
        nsView.onSlashCommit = onSlashCommit
        nsView.onEscape = onEscape
        nsView.onSelectAllBlocks = onSelectAllBlocks
        nsView.onFocus = onFocus
        nsView.onFormattingStateChanged = onFormattingStateChanged
        nsView.onHeightChange = { newH in
            if abs(dynamicHeight - newH) > 1 {
                dynamicHeight = newH
            }
        }

        let styled = MarkdownStyler.markdownToAttributedString(text, baseFont: font, baseColor: textColor)
        if nsView.attributedString() != styled && nsView.textStorage?.string != styled.string {
            let prevRange = nsView.selectedRange()
            nsView.textStorage?.setAttributedString(styled)
            if prevRange.location <= (styled.string as NSString).length {
                nsView.setSelectedRange(prevRange)
            }
            nsView.recalculateHeight()
        }

        if isFocused {
            if !context.coordinator.didFocusOnce {
                context.coordinator.didFocusOnce = true
                let focusBlock = {
                    if let window = nsView.window, window.firstResponder != nsView {
                        window.makeFirstResponder(nsView)
                    }
                    let len = (nsView.string as NSString).length
                    nsView.setSelectedRange(NSRange(location: len, length: 0))
                }
                if nsView.window != nil {
                    focusBlock()
                } else {
                    DispatchQueue.main.async {
                        focusBlock()
                    }
                }
            }
        } else {
            context.coordinator.didFocusOnce = false
        }
        nsView.needsDisplay = true
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: BlockEditorTextView, context: Context) -> CGSize? {
        let targetWidth = proposal.width ?? nsView.frame.width
        guard targetWidth > 0 else { return nil }
        if nsView.frame.width != targetWidth {
            nsView.frame.size.width = targetWidth
            nsView.textContainer?.containerSize = NSSize(width: targetWidth, height: .greatestFiniteMagnitude)
        }
        if let lm = nsView.layoutManager, let tc = nsView.textContainer {
            lm.ensureLayout(for: tc)
            let used = lm.usedRect(for: tc)
            let minH = (nsView.font?.pointSize ?? 15) * 1.35
            let h = ceil(max(used.height + nsView.textContainerInset.height * 2, minH))
            return CGSize(width: targetWidth, height: h)
        }
        return nil
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: BlockEditorField
        var didFocusOnce: Bool = false
        static weak var activeTextView: NSTextView?

        init(_ parent: BlockEditorField) {
            self.parent = parent
        }

        func textDidBeginEditing(_ notification: Notification) {
            if let tv = notification.object as? BlockEditorTextView {
                Coordinator.activeTextView = tv
                tv.updateFormattingState()
                tv.recalculateHeight()
            }
            parent.onFocus?()
        }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? BlockEditorTextView else { return }
            Coordinator.activeTextView = tv

            // Auto-convert typed markdown delimiters (e.g. typing **bold** or ~~strike~~) into real WYSIWYG
            let rawStr = tv.string
            if rawStr.contains("**") || rawStr.contains("~~") || rawStr.contains("==") {
                let styled = MarkdownStyler.markdownToAttributedString(rawStr, baseFont: parent.font, baseColor: parent.textColor)
                if styled.string != rawStr {
                    let sel = tv.selectedRange()
                    tv.textStorage?.setAttributedString(styled)
                    let safeLoc = min(sel.location, (styled.string as NSString).length)
                    tv.setSelectedRange(NSRange(location: safeLoc, length: 0))
                }
            }

            let md = MarkdownStyler.attributedStringToMarkdown(tv.attributedString())
            parent.text = md
            parent.onTextChanged?(md)
            tv.updateFormattingState()
            tv.recalculateHeight()
            tv.needsDisplay = true
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let tv = notification.object as? BlockEditorTextView else { return }
            Coordinator.activeTextView = tv
            tv.updateFormattingState()
        }
    }
}

// MARK: - Google Colab Style Block Insertion Divider

struct ColabInsertLineView: View {
    let onInsertText: () -> Void
    let onInsertKind: (UIBlockKind) -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        ZStack {
            // Subtle horizontal dividing line visible on hover
            if isHovered {
                Rectangle()
                    .fill(Color.accentColor.opacity(0.35))
                    .frame(height: 1.5)
            } else {
                Color.clear
                    .frame(height: 1.5)
            }

            // Google Colab Style Insert Buttons
            if isHovered {
                HStack(spacing: 6) {
                    // Quick "+ Block" pill
                    Button(action: onInsertText) {
                        HStack(spacing: 3) {
                            Image(systemName: "plus")
                                .font(.system(size: 9, weight: .bold))
                            Text("Block")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 3)
                        .background(Color(nsColor: .windowBackgroundColor))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.accentColor.opacity(0.45), lineWidth: 1))
                        .shadow(color: Color.black.opacity(0.08), radius: 3, y: 1)
                    }
                    .buttonStyle(.plain)

                    // Quick "+ Table" pill
                    Button(action: {
                        onInsertKind(.grid(
                            headers: ["Column 1", "Column 2", "Column 3"],
                            rows: [["", "", ""], ["", "", ""]]
                        ))
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: "tablecells")
                                .font(.system(size: 9, weight: .medium))
                            Text("Table")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 3)
                        .background(Color(nsColor: .windowBackgroundColor))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.secondary.opacity(0.3), lineWidth: 1))
                        .shadow(color: Color.black.opacity(0.08), radius: 3, y: 1)
                    }
                    .buttonStyle(.plain)

                    // Quick "+ More" menu pill
                    Menu {
                        Section("Basic Blocks") {
                            Button("Heading 1") { onInsertKind(.heading(level: 1)) }
                            Button("Heading 2") { onInsertKind(.heading(level: 2)) }
                            Button("Heading 3") { onInsertKind(.heading(level: 3)) }
                            Button("To-do List") { onInsertKind(.todo(checked: false)) }
                            Button("Bulleted List") { onInsertKind(.bullet) }
                            Button("Numbered List") { onInsertKind(.numbered(index: 1)) }
                            Button("Toggle List") { onInsertKind(.toggle(isExpanded: false)) }
                            Button("Quote") { onInsertKind(.quote) }
                            Button("Divider") { onInsertKind(.divider) }
                        }
                        Section("Callouts") {
                            Button("💡 Info Callout") { onInsertKind(.callout(icon: "💡", theme: .blue)) }
                            Button("⚠️ Warning Callout") { onInsertKind(.callout(icon: "⚠️", theme: .red)) }
                            Button("✅ Tip Callout") { onInsertKind(.callout(icon: "✅", theme: .green)) }
                        }
                        Section("Media & Code") {
                            Button("Code Block") { onInsertKind(.code(lang: "rust")) }
                            Button("Math Formula") { onInsertKind(.math(expression: "")) }
                            Button("Web Bookmark") { onInsertKind(.bookmark(url: "https://")) }
                            Button("Image") { onInsertKind(.image(url: "", caption: "")) }
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Text("More")
                                .font(.system(size: 11, weight: .medium))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 7))
                        }
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(nsColor: .windowBackgroundColor))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.secondary.opacity(0.3), lineWidth: 1))
                        .shadow(color: Color.black.opacity(0.08), radius: 3, y: 1)
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .frame(height: 18)
        .contentShape(Rectangle())
        .onHover { h in
            withAnimation(.easeInOut(duration: 0.12)) {
                isHovered = h
            }
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
    SlashCommandItem(id: "table", title: "Table / Grid", desc: "Interactive data table with columns and rows.", icon: "tablecells", keywords: ["table", "grid", "column", "columns", "data"], kind: .grid(headers: ["Column 1", "Column 2", "Column 3"], rows: [["", "", ""], ["", "", ""]]))
]

// MARK: - Block Frame Preference for Marquee Selection

struct BlockFrameItem: Equatable {
    let id: String
    let frame: CGRect
}

struct BlockFramePreferenceKey: PreferenceKey {
    static var defaultValue: [BlockFrameItem] = []
    static func reduce(value: inout [BlockFrameItem], nextValue: () -> [BlockFrameItem]) {
        value.append(contentsOf: nextValue())
    }
}

// MARK: - Block List View

struct BlockListView: View {
    @ObservedObject var store: WorkspaceStore
    let page: DocumentPage
    @Binding var focusedBlockId: String?
    @Binding var selectedBlockIds: Set<String>
    @Binding var blockActionTrigger: BlockActionCommand?
    @Binding var formattingState: EditorFormattingState

    @State private var blocks: [UIBlockItem] = []
    @State private var hoveredBlockId: String? = nil
    @State private var draggedBlock: UIBlockItem? = nil
    @State private var lastClickedBlockId: String? = nil
    @State private var blockFrames: [String: CGRect] = [:]
    @State private var marqueeRect: CGRect? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(blocks.enumerated()), id: \.element.id) { index, block in
                blockItemView(index: index, block: block)
            }


            // Clickable bottom buffer to start writing at end or clear selection
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: 140)
                .contentShape(Rectangle())
                .onTapGesture {
                    if !selectedBlockIds.isEmpty {
                        selectedBlockIds.removeAll()
                        return
                    }
                    insertBlock(at: blocks.count, kind: .paragraph)
                }
        }
        .coordinateSpace(name: "BlockCanvasSpace")
        .onPreferenceChange(BlockFramePreferenceKey.self) { items in
            var map: [String: CGRect] = [:]
            for item in items {
                map[item.id] = item.frame
            }
            self.blockFrames = map
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 6, coordinateSpace: .named("BlockCanvasSpace"))
                .onChanged { gesture in
                    let start = gesture.startLocation
                    let current = gesture.location
                    let rect = CGRect(
                        x: min(start.x, current.x),
                        y: min(start.y, current.y),
                        width: max(1, abs(current.x - start.x)),
                        height: max(1, abs(current.y - start.y))
                    )
                    self.marqueeRect = rect

                    // Once dragging across canvas begins, resign text field responder
                    if self.focusedBlockId != nil {
                        self.focusedBlockId = nil
                        DispatchQueue.main.async {
                            NSApp.keyWindow?.makeFirstResponder(nil)
                        }
                    }

                    var newlySelected = Set<String>()
                    for (id, frame) in self.blockFrames {
                        if rect.intersects(frame) {
                            newlySelected.insert(id)
                        }
                    }
                    self.selectedBlockIds = newlySelected
                }
                .onEnded { _ in
                    self.marqueeRect = nil
                }
        )
        .overlay(
            Group {
                if let rect = marqueeRect {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.accentColor.opacity(0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 3)
                                .stroke(Color.accentColor.opacity(0.65), lineWidth: 1)
                        )
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                }
            }
            .allowsHitTesting(false)
        )
        .onAppear {
            self.blocks = store.parseToUIBlocks(content: page.rawContent)
        }
        .onChange(of: page.id) { _, _ in
            self.blocks = store.parseToUIBlocks(content: page.rawContent)
            self.selectedBlockIds.removeAll()
        }
        .onChange(of: blockActionTrigger) { _, cmd in
            guard let cmd = cmd else { return }
            switch cmd {
            case .deleteSelected:
                deleteSelectedBlocks()
            case .duplicateSelected:
                duplicateSelectedBlocks()
            case .transformSelected(let kind):
                transformSelectedBlocks(to: kind)
            case .selectAll:
                selectAllBlocks()
            case .clearSelection:
                selectedBlockIds.removeAll()
            case .insertBlock(let kind):
                insertBlockFromToolbar(kind: kind)
            case .formatActiveBlock(let marker):
                formatActiveBlock(marker: marker)
            }
            blockActionTrigger = nil
        }
    }

    @ViewBuilder
    private func blockItemView(index: Int, block: UIBlockItem) -> some View {
        VStack(spacing: 0) {
            BlockRowView(
                store: store,
                block: block,
                isHovered: hoveredBlockId == block.id,
                isSelected: selectedBlockIds.contains(block.id),
                isFirstBlock: index == 0,
                isLastBlock: index == blocks.count - 1,
                isFocused: focusedBlockId == block.id,
                formattingState: $formattingState,
                onFocus: {
                    focusedBlockId = block.id
                    if !selectedBlockIds.contains(block.id) {
                        selectedBlockIds.removeAll()
                    }
                },
                onSelectHandle: {
                    handleBlockHandleClick(block: block)
                },
                onSelectAllBlocks: {
                    selectAllBlocks()
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
                    insertBlock(at: index + 1, kind: kind, initialText: initialText)
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
                    self.focusedBlockId = newId
                },
                onDelete: {
                    deleteBlockAt(index: index)
                },
                onDeleteEmpty: {
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
            .background(
                GeometryReader { geo in
                    Color.clear.preference(
                        key: BlockFramePreferenceKey.self,
                        value: [BlockFrameItem(id: block.id, frame: geo.frame(in: .named("BlockCanvasSpace")))]
                    )
                }
            )
            .onHover { isHovered in
                if isHovered {
                    hoveredBlockId = block.id
                } else if hoveredBlockId == block.id {
                    hoveredBlockId = nil
                }
            }
            .onDrop(of: [UTType(importedAs: "com.pustaka.block-drag")], delegate: BlockDropDelegate(
                item: block,
                blocks: $blocks,
                draggedItem: $draggedBlock,
                onComplete: { syncBackToStore() }
            ))

            // Google Colab Style Hover Insert Line between blocks
            ColabInsertLineView(
                onInsertText: {
                    insertBlock(at: index + 1, kind: .paragraph)
                },
                onInsertKind: { kind in
                    insertBlock(at: index + 1, kind: kind)
                }
            )
        }
    }

    private func insertBlock(at targetIndex: Int, kind: UIBlockKind, initialText: String = "") {
        let newId = "blk_\(UUID().uuidString.prefix(6))"
        let newBlock = UIBlockItem(id: newId, kind: kind, text: initialText)
        let safeIndex = min(max(0, targetIndex), blocks.count)
        blocks.insert(newBlock, at: safeIndex)
        selectedBlockIds.removeAll()
        syncBackToStore()
        self.focusedBlockId = newId
    }

    private func insertBlockFromToolbar(kind: UIBlockKind) {
        let newId = "blk_\(UUID().uuidString.prefix(6))"
        let newBlock = UIBlockItem(id: newId, kind: kind, text: "")
        if let focusedId = focusedBlockId, let idx = blocks.firstIndex(where: { $0.id == focusedId }) {
            blocks.insert(newBlock, at: idx + 1)
        } else {
            blocks.append(newBlock)
        }
        selectedBlockIds.removeAll()
        syncBackToStore()
        self.focusedBlockId = newId
    }

    private func formatActiveBlock(marker: String) {
        // 1. If text is selected in the currently focused or active NSTextView, toggle formatting trait directly without inserting raw asterisks/markers!
        let activeTV = (NSApp.keyWindow?.firstResponder as? NSTextView) ?? BlockEditorField.Coordinator.activeTextView
        if let textView = activeTV, let storage = textView.textStorage {
            let range = textView.selectedRange()
            if range.length > 0 {
                storage.beginEditing()
                switch marker {
                case "**":
                    let currentFont = (storage.attribute(.font, at: range.location, effectiveRange: nil) as? NSFont) ?? textView.font ?? NSFont.systemFont(ofSize: 15)
                    let isBold = NSFontManager.shared.traits(of: currentFont).contains(.boldFontMask)
                    let newFont = isBold
                        ? NSFontManager.shared.convert(currentFont, toNotHaveTrait: .boldFontMask)
                        : NSFontManager.shared.convert(currentFont, toHaveTrait: .boldFontMask)
                    storage.addAttribute(.font, value: newFont, range: range)

                case "*":
                    let currentFont = (storage.attribute(.font, at: range.location, effectiveRange: nil) as? NSFont) ?? textView.font ?? NSFont.systemFont(ofSize: 15)
                    let isItalic = NSFontManager.shared.traits(of: currentFont).contains(.italicFontMask)
                    let newFont = isItalic
                        ? NSFontManager.shared.convert(currentFont, toNotHaveTrait: .italicFontMask)
                        : NSFontManager.shared.convert(currentFont, toHaveTrait: .italicFontMask)
                    storage.addAttribute(.font, value: newFont, range: range)

                case "~~":
                    let currentStrike = (storage.attribute(.strikethroughStyle, at: range.location, effectiveRange: nil) as? Int) ?? 0
                    if currentStrike != 0 {
                        storage.removeAttribute(.strikethroughStyle, range: range)
                    } else {
                        storage.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: range)
                    }

                case "`":
                    let currentBg = storage.attribute(.backgroundColor, at: range.location, effectiveRange: nil) as? NSColor
                    if currentBg == NSColor.quaternaryLabelColor {
                        let baseFont = textView.font ?? NSFont.systemFont(ofSize: 15)
                        storage.addAttribute(.font, value: baseFont, range: range)
                        storage.removeAttribute(.backgroundColor, range: range)
                        storage.removeAttribute(.foregroundColor, range: range)
                    } else {
                        let codeFont = NSFont.monospacedSystemFont(ofSize: (textView.font?.pointSize ?? 15) * 0.9, weight: .regular)
                        storage.addAttribute(.font, value: codeFont, range: range)
                        storage.addAttribute(.backgroundColor, value: NSColor.quaternaryLabelColor, range: range)
                        storage.addAttribute(.foregroundColor, value: NSColor.systemRed, range: range)
                    }

                default:
                    break
                }
                storage.endEditing()
                textView.didChangeText()
                if let blockTV = textView as? BlockEditorTextView {
                    blockTV.updateFormattingState()
                }
                return
            } else if textView.window?.firstResponder == textView {
                var attrs = textView.typingAttributes
                let currentFont = (attrs[.font] as? NSFont) ?? textView.font ?? NSFont.systemFont(ofSize: 15)
                switch marker {
                case "**":
                    let isBold = NSFontManager.shared.traits(of: currentFont).contains(.boldFontMask)
                    attrs[.font] = isBold
                        ? NSFontManager.shared.convert(currentFont, toNotHaveTrait: .boldFontMask)
                        : NSFontManager.shared.convert(currentFont, toHaveTrait: .boldFontMask)
                case "*":
                    let isItalic = NSFontManager.shared.traits(of: currentFont).contains(.italicFontMask)
                    attrs[.font] = isItalic
                        ? NSFontManager.shared.convert(currentFont, toNotHaveTrait: .italicFontMask)
                        : NSFontManager.shared.convert(currentFont, toHaveTrait: .italicFontMask)
                case "~~":
                    let current = (attrs[.strikethroughStyle] as? Int) ?? 0
                    if current != 0 {
                        attrs.removeValue(forKey: .strikethroughStyle)
                    } else {
                        attrs[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
                    }
                case "`":
                    if attrs[.backgroundColor] != nil {
                        attrs.removeValue(forKey: .backgroundColor)
                        attrs.removeValue(forKey: .foregroundColor)
                        attrs[.font] = textView.font ?? NSFont.systemFont(ofSize: 15)
                    } else {
                        attrs[.font] = NSFont.monospacedSystemFont(ofSize: (textView.font?.pointSize ?? 15) * 0.9, weight: .regular)
                        attrs[.backgroundColor] = NSColor.quaternaryLabelColor
                        attrs[.foregroundColor] = NSColor.systemRed
                    }
                default:
                    break
                }
                textView.typingAttributes = attrs
                if let blockTV = textView as? BlockEditorTextView {
                    blockTV.updateFormattingState()
                }
                return
            }
        }

        // 2. Multi-block selection formatting
        if !selectedBlockIds.isEmpty {
            for i in 0..<blocks.count {
                if selectedBlockIds.contains(blocks[i].id) {
                    blocks[i].text = toggleMarkdownFormatting(in: blocks[i].text, marker: marker)
                }
            }
            syncBackToStore()
            return
        }

        // 3. Fallback: Entire active block
        if let focusedId = focusedBlockId, let idx = blocks.firstIndex(where: { $0.id == focusedId }) {
            blocks[idx].text = toggleMarkdownFormatting(in: blocks[idx].text, marker: marker)
            syncBackToStore()
        }
    }

    private func toggleMarkdownFormatting(in text: String, marker: String) -> String {
        let baseFont = NSFont.systemFont(ofSize: 15)
        let attr = MarkdownStyler.markdownToAttributedString(text, baseFont: baseFont)
        let mutable = NSMutableAttributedString(attributedString: attr)
        let full = NSRange(location: 0, length: mutable.length)
        guard full.length > 0 else { return text }

        switch marker {
        case "**":
            let font = (mutable.attribute(.font, at: 0, effectiveRange: nil) as? NSFont) ?? baseFont
            let isBold = NSFontManager.shared.traits(of: font).contains(.boldFontMask)
            let newFont = isBold
                ? NSFontManager.shared.convert(font, toNotHaveTrait: .boldFontMask)
                : NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
            mutable.addAttribute(.font, value: newFont, range: full)
            formattingState.isBold = !isBold
        case "*":
            let font = (mutable.attribute(.font, at: 0, effectiveRange: nil) as? NSFont) ?? baseFont
            let isItalic = NSFontManager.shared.traits(of: font).contains(.italicFontMask)
            let newFont = isItalic
                ? NSFontManager.shared.convert(font, toNotHaveTrait: .italicFontMask)
                : NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
            mutable.addAttribute(.font, value: newFont, range: full)
            formattingState.isItalic = !isItalic
        case "~~":
            let currentStrike = (mutable.attribute(.strikethroughStyle, at: 0, effectiveRange: nil) as? Int) ?? 0
            if currentStrike != 0 {
                mutable.removeAttribute(.strikethroughStyle, range: full)
                formattingState.isStrike = false
            } else {
                mutable.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: full)
                formattingState.isStrike = true
            }
        case "`":
            let currentBg = mutable.attribute(.backgroundColor, at: 0, effectiveRange: nil) as? NSColor
            if currentBg == NSColor.quaternaryLabelColor {
                mutable.addAttribute(.font, value: baseFont, range: full)
                mutable.removeAttribute(.backgroundColor, range: full)
                mutable.removeAttribute(.foregroundColor, range: full)
                formattingState.isCode = false
            } else {
                let codeFont = NSFont.monospacedSystemFont(ofSize: 15 * 0.9, weight: .regular)
                mutable.addAttribute(.font, value: codeFont, range: full)
                mutable.addAttribute(.backgroundColor, value: NSColor.quaternaryLabelColor, range: full)
                mutable.addAttribute(.foregroundColor, value: NSColor.systemRed, range: full)
                formattingState.isCode = true
            }
        default:
            break
        }
        return MarkdownStyler.attributedStringToMarkdown(mutable)
    }

    // MARK: - Multi-Selection Operations

    private func handleBlockHandleClick(block: UIBlockItem) {
        let isShift = NSEvent.modifierFlags.contains(.shift)
        let isCmd = NSEvent.modifierFlags.contains(.command)

        if isShift, let lastId = lastClickedBlockId,
           let fromIdx = blocks.firstIndex(where: { $0.id == lastId }),
           let toIdx = blocks.firstIndex(where: { $0.id == block.id }) {
            let range = min(fromIdx, toIdx)...max(fromIdx, toIdx)
            for idx in range {
                selectedBlockIds.insert(blocks[idx].id)
            }
        } else if isCmd {
            if selectedBlockIds.contains(block.id) {
                selectedBlockIds.remove(block.id)
            } else {
                selectedBlockIds.insert(block.id)
            }
            lastClickedBlockId = block.id
        } else {
            if selectedBlockIds == [block.id] {
                selectedBlockIds.removeAll()
                lastClickedBlockId = nil
            } else {
                selectedBlockIds = [block.id]
                lastClickedBlockId = block.id
            }
        }
        // Resign text focus when selecting blocks via handle
        focusedBlockId = nil
    }

    private func selectAllBlocks() {
        selectedBlockIds = Set(blocks.map(\.id))
        focusedBlockId = nil
    }

    private func deleteSelectedBlocks() {
        if !selectedBlockIds.isEmpty {
            blocks.removeAll { selectedBlockIds.contains($0.id) }
            if blocks.isEmpty {
                blocks = [UIBlockItem(id: "blk_1", kind: .paragraph, text: "")]
            }
            selectedBlockIds.removeAll()
            syncBackToStore()
            return
        }

        if let focusedId = focusedBlockId, let idx = blocks.firstIndex(where: { $0.id == focusedId }) {
            deleteBlockAt(index: idx)
        }
    }

    private func duplicateSelectedBlocks() {
        if !selectedBlockIds.isEmpty {
            var newBlocks: [UIBlockItem] = []
            var newSelectedIds: Set<String> = []

            for block in blocks {
                newBlocks.append(block)
                if selectedBlockIds.contains(block.id) {
                    let dupId = "blk_\(UUID().uuidString.prefix(6))"
                    let dup = UIBlockItem(id: dupId, kind: block.kind, text: block.text)
                    newBlocks.append(dup)
                    newSelectedIds.insert(dupId)
                }
            }

            blocks = newBlocks
            selectedBlockIds = newSelectedIds
            syncBackToStore()
            return
        }

        if let focusedId = focusedBlockId, let idx = blocks.firstIndex(where: { $0.id == focusedId }) {
            let dupId = "blk_\(UUID().uuidString.prefix(6))"
            let dup = UIBlockItem(id: dupId, kind: blocks[idx].kind, text: blocks[idx].text)
            blocks.insert(dup, at: idx + 1)
            syncBackToStore()
            self.focusedBlockId = dupId
        }
    }

    private func transformSelectedBlocks(to newKind: UIBlockKind) {
        if !selectedBlockIds.isEmpty {
            for i in 0..<blocks.count {
                if selectedBlockIds.contains(blocks[i].id) {
                    blocks[i].kind = newKind
                }
            }
            syncBackToStore()
            return
        }

        if let focusedId = focusedBlockId, let idx = blocks.firstIndex(where: { $0.id == focusedId }) {
            blocks[idx].kind = newKind
            syncBackToStore()
        }
    }

    private func deleteBlockAt(index: Int) {
        if blocks.count > 1 {
            let prevId = (index > 0) ? blocks[index - 1].id : nil
            blocks.remove(at: index)
            syncBackToStore()
            if let prevId = prevId {
                self.focusedBlockId = prevId
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
    @ObservedObject var store: WorkspaceStore
    let block: UIBlockItem
    let isHovered: Bool
    let isSelected: Bool
    let isFirstBlock: Bool
    let isLastBlock: Bool
    let isFocused: Bool
    @Binding var formattingState: EditorFormattingState
    let onFocus: () -> Void
    let onSelectHandle: () -> Void
    let onSelectAllBlocks: () -> Void
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
    @State private var dynamicHeight: CGFloat = 26
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
                // Left Gutter: 6-dots drag handle (width: 14pt)
                dragHandleControl
                    .padding(.top, topGutterPadding)

                // Main Block Content Body
                blockContentBody
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Inline Filtered Notion Slash Command Palette
            if isSlashCommandOpen {
                slashCommandPaletteView
                    .padding(.leading, 20)
                    .padding(.top, 4)
            }
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 2)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor.opacity(0.14) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isSelected ? Color.accentColor.opacity(0.4) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onAppear {
            self.textBuffer = block.text
        }
        .onChange(of: block.text) { _, newVal in
            if self.textBuffer != newVal {
                self.textBuffer = newVal
            }
        }
        .onChange(of: textBuffer) { _, newVal in
            if block.text != newVal {
                onUpdateText(newVal)
            }
        }
    }

    // MARK: - Left Gutter Handle: [::] (Width: 14pt)

    private var dragHandleControl: some View {
        Button(action: onSelectHandle) {
            SixDotsHandleView()
                .frame(width: 14, height: 18)
                .background(isSelected ? Color.accentColor.opacity(0.25) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 3))
        }
        .buttonStyle(.plain)
        .help("Click to select, Shift+Click to range select, or drag to move")
        .accessibilityLabel("Block handle: click to select or drag to rearrange")
        .contextMenu {
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
        }
        .onDrag {
            onStartDrag()
            let provider = NSItemProvider()
            provider.registerDataRepresentation(forTypeIdentifier: "com.pustaka.block-drag", visibility: .all) { completion in
                completion(Data(block.id.utf8), nil)
                return nil
            }
            return provider
        }
        .frame(width: 14)
        .opacity((isHovered || isSelected) ? 1.0 : 0.0)
        .animation(.easeInOut(duration: 0.12), value: isHovered || isSelected)
    }

    // MARK: - Block Content Body

    @ViewBuilder
    private var blockContentBody: some View {
        switch block.kind {
        // 1. Headings
        case .heading(let level):
            BlockEditorField(
                text: $textBuffer,
                dynamicHeight: $dynamicHeight,
                placeholder: (isFocused && textBuffer.isEmpty) ? "Heading \(level)..." : "",
                font: NSFont.systemFont(ofSize: headingFontSize(level), weight: .bold),
                textColor: .labelColor,
                isFocused: isFocused,
                onCommit: {
                    onInsertBelow(.paragraph, "")
                },
                onDeleteEmpty: onDeleteEmpty,
                onSlashCommit: handleSlashCommit,
                onEscape: { isSlashCommandOpen = false; return true },
                onTextChanged: checkSlashCommand,
                onFocus: onFocus,
                onSelectAllBlocks: onSelectAllBlocks,
                onFormattingStateChanged: { state in formattingState = state }
            )
            .frame(minHeight: dynamicHeight, alignment: .topLeading)

        // 2. Plain Text Paragraph
        case .paragraph:
            BlockEditorField(
                text: $textBuffer,
                dynamicHeight: $dynamicHeight,
                placeholder: (isFocused && textBuffer.isEmpty) ? "Type '/' for commands, or start writing..." : "",
                font: NSFont.systemFont(ofSize: 15),
                textColor: .labelColor,
                isFocused: isFocused,
                onCommit: {
                    onInsertBelow(.paragraph, "")
                },
                onDeleteEmpty: onDeleteEmpty,
                onSlashCommit: handleSlashCommit,
                onEscape: { isSlashCommandOpen = false; return true },
                onTextChanged: checkSlashCommand,
                onFocus: onFocus,
                onSelectAllBlocks: onSelectAllBlocks,
                onFormattingStateChanged: { state in formattingState = state }
            )
            .frame(minHeight: dynamicHeight, alignment: .topLeading)

        // 3. Bulleted List
        case .bullet:
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("•")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 10)

                BlockEditorField(
                    text: $textBuffer,
                    dynamicHeight: $dynamicHeight,
                    placeholder: (isFocused && textBuffer.isEmpty) ? "List item..." : "",
                    font: NSFont.systemFont(ofSize: 15),
                    textColor: .labelColor,
                    isFocused: isFocused,
                    onCommit: {
                        onInsertBelow(.bullet, "")
                    },
                    onDeleteEmpty: onDeleteEmpty,
                    onSlashCommit: handleSlashCommit,
                    onEscape: { isSlashCommandOpen = false; return true },
                    onTextChanged: checkSlashCommand,
                    onFocus: onFocus,
                    onSelectAllBlocks: onSelectAllBlocks,
                    onFormattingStateChanged: { state in formattingState = state }
                )
                .frame(minHeight: dynamicHeight, alignment: .topLeading)
            }

        // 4. Numbered List
        case .numbered(let idx):
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(idx).")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 18, alignment: .trailing)

                BlockEditorField(
                    text: $textBuffer,
                    dynamicHeight: $dynamicHeight,
                    placeholder: (isFocused && textBuffer.isEmpty) ? "List item..." : "",
                    font: NSFont.systemFont(ofSize: 15),
                    textColor: .labelColor,
                    isFocused: isFocused,
                    onCommit: {
                        onInsertBelow(.numbered(index: idx + 1), "")
                    },
                    onDeleteEmpty: onDeleteEmpty,
                    onSlashCommit: handleSlashCommit,
                    onEscape: { isSlashCommandOpen = false; return true },
                    onTextChanged: checkSlashCommand,
                    onFocus: onFocus,
                    onSelectAllBlocks: onSelectAllBlocks,
                    onFormattingStateChanged: { state in formattingState = state }
                )
                .frame(minHeight: dynamicHeight, alignment: .topLeading)
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
                    .accessibilityLabel(isExpanded ? "Collapse toggle" : "Expand toggle")

                    BlockEditorField(
                        text: $textBuffer,
                        dynamicHeight: $dynamicHeight,
                        placeholder: (isFocused && textBuffer.isEmpty) ? "Toggle list heading..." : "",
                        font: NSFont.systemFont(ofSize: 15, weight: .semibold),
                        textColor: .labelColor,
                        isFocused: isFocused,
                        onCommit: {
                            onInsertBelow(.paragraph, "")
                        },
                        onDeleteEmpty: onDeleteEmpty,
                        onSlashCommit: handleSlashCommit,
                        onEscape: { isSlashCommandOpen = false; return true },
                        onTextChanged: checkSlashCommand,
                        onFocus: onFocus,
                        onSelectAllBlocks: onSelectAllBlocks,
                        onFormattingStateChanged: { state in formattingState = state }
                    )
                    .frame(minHeight: dynamicHeight, alignment: .topLeading)
                }

                if isExpanded {
                    Text("Empty toggle. Press '+' below to add child blocks.")
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
                    dynamicHeight: $dynamicHeight,
                    placeholder: (isFocused && textBuffer.isEmpty) ? "Quote..." : "",
                    font: NSFont.systemFont(ofSize: 15),
                    textColor: .secondaryLabelColor,
                    isFocused: isFocused,
                    onCommit: {
                        onInsertBelow(.paragraph, "")
                    },
                    onDeleteEmpty: onDeleteEmpty,
                    onSlashCommit: handleSlashCommit,
                    onEscape: { isSlashCommandOpen = false; return true },
                    onTextChanged: checkSlashCommand,
                    onFocus: onFocus,
                    onSelectAllBlocks: onSelectAllBlocks,
                    onFormattingStateChanged: { state in formattingState = state }
                )
                .frame(minHeight: dynamicHeight, alignment: .topLeading)
            }
            .padding(.vertical, 2)

        // 7. Divider Block (With hover delete action)
        case .divider:
            HStack(spacing: 8) {
                Divider()
                    .frame(height: 1)

                if isHovered || isSelected {
                    Button(role: .destructive, action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 10))
                            .foregroundStyle(.red.opacity(0.75))
                    }
                    .buttonStyle(.plain)
                    .help("Delete Divider")
                    .accessibilityLabel("Delete divider")
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
                .accessibilityLabel(checked ? "Completed task" : "Incomplete task")

                BlockEditorField(
                    text: $textBuffer,
                    dynamicHeight: $dynamicHeight,
                    placeholder: (isFocused && textBuffer.isEmpty) ? "To-do..." : "",
                    font: NSFont.systemFont(ofSize: 15),
                    textColor: checked ? .secondaryLabelColor : .labelColor,
                    isFocused: isFocused,
                    onCommit: {
                        onInsertBelow(.todo(checked: false), "")
                    },
                    onDeleteEmpty: onDeleteEmpty,
                    onSlashCommit: handleSlashCommit,
                    onEscape: { isSlashCommandOpen = false; return true },
                    onTextChanged: checkSlashCommand,
                    onFocus: onFocus,
                    onSelectAllBlocks: onSelectAllBlocks,
                    onFormattingStateChanged: { state in formattingState = state }
                )
                .frame(minHeight: dynamicHeight, alignment: .topLeading)
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
                    dynamicHeight: $dynamicHeight,
                    placeholder: (isFocused && textBuffer.isEmpty) ? "Callout note..." : "",
                    font: NSFont.systemFont(ofSize: 15),
                    textColor: .labelColor,
                    isFocused: isFocused,
                    onCommit: {
                        onInsertBelow(.paragraph, "")
                    },
                    onDeleteEmpty: onDeleteEmpty,
                    onSlashCommit: handleSlashCommit,
                    onEscape: { isSlashCommandOpen = false; return true },
                    onTextChanged: checkSlashCommand,
                    onFocus: onFocus,
                    onSelectAllBlocks: onSelectAllBlocks,
                    onFormattingStateChanged: { state in formattingState = state }
                )
                .frame(minHeight: dynamicHeight, alignment: .topLeading)

                if isHovered || isSelected {
                    Button(role: .destructive, action: onDelete) {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundStyle(.red.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    .help("Delete Callout")
                    .accessibilityLabel("Delete callout")
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
                        dynamicHeight: $dynamicHeight,
                        placeholder: (isFocused && textBuffer.isEmpty) ? "Bookmark Title..." : "",
                        font: NSFont.systemFont(ofSize: 14, weight: .semibold),
                        textColor: .labelColor,
                        isFocused: isFocused,
                        onCommit: {
                            onInsertBelow(.paragraph, "")
                        },
                        onDeleteEmpty: onDeleteEmpty,
                        onSlashCommit: handleSlashCommit,
                        onEscape: { isSlashCommandOpen = false; return true },
                        onTextChanged: checkSlashCommand,
                        onFocus: onFocus,
                        onSelectAllBlocks: onSelectAllBlocks,
                        onFormattingStateChanged: { state in formattingState = state }
                    )
                    .frame(minHeight: dynamicHeight, alignment: .topLeading)

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
                        .accessibilityLabel("Open bookmark in browser")
                    }

                    Button(role: .destructive, action: onDelete) {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundStyle(.red.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    .help("Delete Bookmark")
                    .accessibilityLabel("Delete bookmark")
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
                    .accessibilityLabel("Bookmark URL")
                }
            }
            .padding(10)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )

        // 11. Image Block (Preview, Online URL, Local File Upload, Caption & Delete)
        case .image(let url, let caption):
            VStack(alignment: .leading, spacing: 6) {
                if !url.isEmpty {
                    if (url.hasPrefix("http://") || url.hasPrefix("https://")), let imgUrl = URL(string: url) {
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
                                    .frame(maxHeight: 320)
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
                    } else if let localPath = store.resolveVaultImagePath(url),
                              let nsImg = NSImage(contentsOfFile: localPath) {
                        Image(nsImage: nsImg)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 320)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    } else if (url.hasPrefix("/") || url.hasPrefix("file://")),
                              let nsImg = NSImage(contentsOfFile: url.replacingOccurrences(of: "file://", with: "")) {
                        Image(nsImage: nsImg)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 320)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    } else {
                        VStack(spacing: 4) {
                            Image(systemName: "photo.badge.exclamationmark")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                            Text("Could not load image file: \(url)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 90)
                        .background(Color.secondary.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }

                HStack(spacing: 8) {
                    Image(systemName: "photo")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    TextField("Image URL or local path...", text: Binding(
                        get: { url },
                        set: { newUrl in
                            onTransformKind(.image(url: newUrl, caption: caption))
                        }
                    ))
                    .textFieldStyle(.plain)
                    .font(.caption)
                    .accessibilityLabel("Image URL or Path")

                    // Upload Local Image File
                    Button(action: {
                        if let localAsset = store.importLocalImageToVault() {
                            onTransformKind(.image(url: localAsset, caption: caption))
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.doc")
                                .font(.system(size: 9, weight: .bold))
                            Text("Upload File")
                                .font(.caption.weight(.medium))
                        }
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.accentColor.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                    }
                    .buttonStyle(.plain)
                    .help("Upload image from your computer")

                    Spacer()

                    Button(role: .destructive, action: onDelete) {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundStyle(.red.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    .help("Delete Image")
                    .accessibilityLabel("Delete image")
                }

                BlockEditorField(
                    text: $textBuffer,
                    dynamicHeight: $dynamicHeight,
                    placeholder: (isFocused && textBuffer.isEmpty) ? "Add a caption (optional)..." : "",
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
                    },
                    onFocus: onFocus,
                    onSelectAllBlocks: onSelectAllBlocks,
                    onFormattingStateChanged: { state in formattingState = state }
                )
                .frame(minHeight: dynamicHeight, alignment: .topLeading)
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
                    .accessibilityLabel("Delete math formula")
                }

                BlockEditorField(
                    text: $textBuffer,
                    dynamicHeight: $dynamicHeight,
                    placeholder: (isFocused && textBuffer.isEmpty) ? "e.g. E = mc^2 or \\int_0^\\infty e^{-x} dx" : "",
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
                    },
                    onFocus: onFocus,
                    onSelectAllBlocks: onSelectAllBlocks,
                    onFormattingStateChanged: { state in formattingState = state }
                )
                .frame(minHeight: dynamicHeight, alignment: .topLeading)

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
                    .accessibilityLabel("Select programming language")

                    Spacer()

                    Button("Copy") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(textBuffer, forType: .string)
                    }
                    .buttonStyle(.borderless)
                    .font(.caption2)
                    .accessibilityLabel("Copy code snippet")

                    Button(role: .destructive, action: onDelete) {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundStyle(.red.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    .help("Delete Code Block")
                    .accessibilityLabel("Delete code block")
                }

                TextEditor(text: $textBuffer)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 70)
                    .scrollContentBackground(.hidden)
                    .onChange(of: textBuffer) { _, newVal in
                        onUpdateText(newVal)
                    }
                    .accessibilityLabel("Code editor")
            }
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
            )

        // 14. Grid / Modern Interactive Table
        case .grid(let headers, let rows):
            ModernTableView(
                headers: headers,
                rows: rows,
                onUpdateTable: { newHeaders, newRows in
                    onTransformKind(.grid(headers: newHeaders, rows: newRows))
                },
                onInsertBelow: {
                    onInsertBelow(.paragraph, "")
                },
                onDelete: onDelete
            )
        }
    }

    private func checkSlashCommand(_ text: String) {
        if text.hasPrefix("/") {
            isSlashCommandOpen = true
        } else {
            isSlashCommandOpen = false
        }
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
            Button("Table / Grid") {
                onInsertBelow(.grid(
                    headers: ["Column 1", "Column 2", "Column 3"],
                    rows: [["", "", ""], ["", "", ""]]
                ), "")
            }
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
            Button("Table / Grid") {
                onTransformKind(.grid(
                    headers: ["Column 1", "Column 2", "Column 3"],
                    rows: [["", "", ""], ["", "", ""]]
                ))
            }
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

// MARK: - Notion-Style Table View (Clean grid with proper borders and cell editing)

struct ModernTableView: View {
    let headers: [String]
    let rows: [[String]]
    let onUpdateTable: ([String], [[String]]) -> Void
    let onInsertBelow: () -> Void
    let onDelete: () -> Void

    @State private var hoveredRowIdx: Int? = nil
    @State private var hoveredColIdx: Int? = nil
    @State private var isTableHovered: Bool = false

    private let cellHeight: CGFloat = 34
    private let indexGutterWidth: CGFloat = 36

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Table Top Action Bar
            HStack(spacing: 8) {
                Label("Table", systemImage: "tablecells")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)

                Text("\(rows.count) rows × \(headers.count) columns")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.primary.opacity(0.04))
                    .clipShape(Capsule())

                Spacer()

                Button(action: addColumn) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 9, weight: .bold))
                        Text("Column")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.primary.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
                .help("Add Column to Table")

                Button(action: addRow) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 9, weight: .bold))
                        Text("Row")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.primary.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
                .help("Add Row to Table")

                Menu {
                    Button("Add Column", action: addColumn)
                    Button("Add Row", action: addRow)
                    Divider()
                    Button(role: .destructive, action: clearCells) {
                        Label("Clear All Cells", systemImage: "eraser")
                    }
                    Button(role: .destructive, action: onDelete) {
                        Label("Delete Table", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .padding(4)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 2)

            // Table Grid Container stretching full width of canvas
            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    // Header Row
                    HStack(spacing: 0) {
                        // Left index corner
                        Text("#")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.tertiary)
                            .frame(width: indexGutterWidth, height: cellHeight)
                            .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))

                        Rectangle()
                            .fill(Color.secondary.opacity(0.18))
                            .frame(width: 1, height: cellHeight)

                        ForEach(Array(headers.enumerated()), id: \.offset) { colIdx, title in
                            headerCell(colIdx: colIdx, title: title)

                            if colIdx < headers.count - 1 {
                                Rectangle()
                                    .fill(Color.secondary.opacity(0.18))
                                    .frame(width: 1, height: cellHeight)
                            }
                        }

                        // Rightmost + Column button
                        Button(action: addColumn) {
                            Image(systemName: "plus")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.secondary)
                                .frame(width: 32, height: cellHeight)
                        }
                        .buttonStyle(.plain)
                        .background(Color(nsColor: .controlBackgroundColor).opacity(0.4))
                        .help("Add Column")
                    }
                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))

                    Rectangle()
                        .fill(Color.secondary.opacity(0.22))
                        .frame(height: 1)

                    // Data Rows
                    ForEach(Array(rows.enumerated()), id: \.offset) { rowIdx, rowCells in
                        VStack(spacing: 0) {
                            HStack(spacing: 0) {
                                // Left Row Number / Delete Button
                                ZStack {
                                    if hoveredRowIdx == rowIdx {
                                        Button(action: { deleteRow(at: rowIdx) }) {
                                            Image(systemName: "trash")
                                                .font(.system(size: 9))
                                                .foregroundStyle(.red.opacity(0.8))
                                        }
                                        .buttonStyle(.plain)
                                        .help("Delete row")
                                    } else {
                                        Text("\(rowIdx + 1)")
                                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                                .frame(width: indexGutterWidth, height: cellHeight)
                                .background(Color.primary.opacity(0.015))

                                Rectangle()
                                    .fill(Color.secondary.opacity(0.12))
                                    .frame(width: 1, height: cellHeight)

                                ForEach(0..<headers.count, id: \.self) { colIdx in
                                    dataCell(rowIdx: rowIdx, colIdx: colIdx, rowCells: rowCells)

                                    if colIdx < headers.count - 1 {
                                        Rectangle()
                                            .fill(Color.secondary.opacity(0.12))
                                            .frame(width: 1, height: cellHeight)
                                    }
                                }

                                // Match + Column header width
                                Color.clear
                                    .frame(width: 32, height: cellHeight)
                            }
                            .background(
                                hoveredRowIdx == rowIdx
                                    ? Color.accentColor.opacity(0.05)
                                    : (rowIdx % 2 == 1 ? Color.primary.opacity(0.015) : Color.clear)
                            )
                            .onHover { h in
                                if h { hoveredRowIdx = rowIdx }
                                else if hoveredRowIdx == rowIdx { hoveredRowIdx = nil }
                            }

                            if rowIdx < rows.count - 1 {
                                Rectangle()
                                    .fill(Color.secondary.opacity(0.1))
                                    .frame(height: 1)
                            }
                        }
                    }

                    Rectangle()
                        .fill(Color.secondary.opacity(0.15))
                        .frame(height: 1)

                    // Bottom "New Row" strip inside table
                    Button(action: addRow) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus")
                                .font(.system(size: 10, weight: .semibold))
                            Text("New row")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, indexGutterWidth + 10)
                        .frame(height: 30)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .background(Color.primary.opacity(0.02))
                }
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )

                // Unmissable "+ Add block below table" button
                Button(action: onInsertBelow) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .bold))
                        Text("Add block below table")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.primary.opacity(0.03))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.secondary.opacity(0.18), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onHover { isTableHovered = $0 }
    }

    // MARK: - Header Cell

    @ViewBuilder
    private func headerCell(colIdx: Int, title: String) -> some View {
        HStack(spacing: 4) {
            TextField("Column \(colIdx + 1)", text: Binding(
                get: { title },
                set: { newTitle in
                    var h = headers
                    h[colIdx] = newTitle
                    onUpdateTable(h, rows)
                }
            ))
            .textFieldStyle(.plain)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.primary)

            if headers.count > 1 && hoveredColIdx == colIdx {
                Button(action: { deleteColumn(at: colIdx) }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.secondary.opacity(0.6))
                        .padding(3)
                        .background(Color.primary.opacity(0.06))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Delete column")
            }
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: cellHeight)
        .onHover { h in
            if h { hoveredColIdx = colIdx }
            else if hoveredColIdx == colIdx { hoveredColIdx = nil }
        }
    }

    // MARK: - Data Cell

    @ViewBuilder
    private func dataCell(rowIdx: Int, colIdx: Int, rowCells: [String]) -> some View {
        let val = colIdx < rowCells.count ? rowCells[colIdx] : ""
        TextField("Empty", text: Binding(
            get: { val },
            set: { newVal in
                var r = rows
                while r[rowIdx].count <= colIdx { r[rowIdx].append("") }
                r[rowIdx][colIdx] = newVal
                onUpdateTable(headers, r)
            }
        ))
        .textFieldStyle(.plain)
        .font(.system(size: 13))
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: cellHeight)
    }

    // MARK: - Table Mutations

    private func addColumn() {
        var h = headers
        h.append("Column \(h.count + 1)")
        var r = rows
        for i in 0..<r.count { r[i].append("") }
        onUpdateTable(h, r)
    }

    private func deleteColumn(at idx: Int) {
        guard headers.count > 1 else { return }
        var h = headers; h.remove(at: idx)
        var r = rows
        for i in 0..<r.count {
            if idx < r[i].count { r[i].remove(at: idx) }
        }
        onUpdateTable(h, r)
    }

    private func addRow() {
        var r = rows
        r.append(Array(repeating: "", count: headers.count))
        onUpdateTable(headers, r)
    }

    private func deleteRow(at idx: Int) {
        guard rows.count > 1 else {
            onUpdateTable(headers, [Array(repeating: "", count: headers.count)])
            return
        }
        var r = rows; r.remove(at: idx)
        onUpdateTable(headers, r)
    }

    private func clearCells() {
        let cleared = rows.map { _ in Array(repeating: "", count: headers.count) }
        onUpdateTable(headers, cleared)
    }
}
