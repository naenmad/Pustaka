import SwiftUI
import AppKit

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

// MARK: - Native Title Editor Field (Supports Enter to Jump to Content)

struct TitleEditorField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var onCommit: () -> Void
    var onTextChanged: (String) -> Void

    func makeNSView(context: Context) -> NSTextField {
        let tf = NSTextField()
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
    @State private var isIconPickerOpen: Bool = false
    @State private var isCoverPickerOpen: Bool = false
    @State private var isCoverHovered: Bool = false
    @State private var isHeaderHovered: Bool = false
    @State private var customEmojiInput: String = ""
    @State private var customCoverUrlInput: String = ""

    // Dynamic accessor ensures immediate reactivity upon store updates
    var currentPage: DocumentPage {
        store.pages.first(where: { $0.id == page.id }) ?? page
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            documentCanvasBody

            // Slide-over Drawer for Typst Live Preview (Toggled with Cmd+P or ... menu)
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
                }
            }

            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(action: {
                        store.duplicatePage(id: currentPage.id)
                    }) {
                        Label("Duplicate Page", systemImage: "plus.square.on.square")
                    }

                    Button(action: {
                        store.toggleFavorite(id: currentPage.id)
                    }) {
                        Label(
                            currentPage.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                            systemImage: currentPage.isFavorite ? "star.fill" : "star"
                        )
                    }

                    Button(action: {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(currentPage.title.isEmpty ? "Untitled" : currentPage.title, forType: .string)
                    }) {
                        Label("Copy Page Title", systemImage: "doc.on.doc")
                    }

                    Divider()

                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            store.isPreviewDrawerPresented.toggle()
                        }
                    }) {
                        Label(
                            store.isPreviewDrawerPresented ? "Hide Typst Preview" : "Show Typst Preview (Cmd+P)",
                            systemImage: "sparkles"
                        )
                    }
                    .keyboardShortcut("p", modifiers: .command)

                    Divider()

                    Button(role: .destructive, action: {
                        store.deletePage(id: currentPage.id)
                    }) {
                        Label("Move to Trash (Delete)", systemImage: "trash")
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

    private func focusFirstBlock() {
        let blocks = store.parseToUIBlocks(content: currentPage.rawContent)
        if let first = blocks.first {
            focusedBlockId = nil
            DispatchQueue.main.async {
                self.focusedBlockId = first.id
            }
        }
    }

    // MARK: - Document Body

    private var documentCanvasBody: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 0) {
                // Cover Image Banner
                if !currentPage.coverUrl.isEmpty {
                    pageCoverBannerView
                }

                // Centered Notion Page Area
                VStack(alignment: .leading, spacing: 14) {
                    notionPageHeaderView

                    BlockListView(store: store, page: currentPage, focusedBlockId: $focusedBlockId)

                    Spacer(minLength: 160)
                }
                .frame(maxWidth: 740)
                .padding(.horizontal, 36)
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

            // Cover Action Buttons: Change cover / Remove
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
            // Action bar: [Add icon] [Add cover] when missing
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

            // Current Page Icon (If present, click to change or remove)
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

            // Page Title (Enter jumps down to document content)
            TitleEditorField(
                text: $titleBuffer,
                placeholder: "Untitled",
                onCommit: {
                    focusFirstBlock()
                },
                onTextChanged: { newTitle in
                    store.updatePageTitle(pageId: currentPage.id, newTitle: newTitle)
                }
            )
            .padding(.top, 2)
        }
        .padding(.leading, 48)
        .contentShape(Rectangle())
        .onHover { isHeaderHovered = $0 }
        // Single, reliably anchored Popovers
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

            // Quick Curated Emoji Grid
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

            // Input / Random / Native Mac Palette
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

                // Native macOS Emoji & Symbols Palette
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

            // Section 1: Vibrant Instant Gradients (Offline & 100% Reliable)
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

            // Section 2: Online Unsplash Curated Photos
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

            // Custom URL & Random Option
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
}
