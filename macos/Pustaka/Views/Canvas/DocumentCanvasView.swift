import SwiftUI

struct DocumentCanvasView: View {
    @ObservedObject var store: WorkspaceStore
    let page: DocumentPage

    @State private var titleBuffer: String = ""
    @State private var isIconPickerOpen: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Top Navigation & View Switcher Bar
            topNavigationBar
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            // Main Canvas Area
            ZStack(alignment: .trailing) {
                switch store.currentViewMode {
                case .document:
                    documentCanvasBody
                case .board:
                    KanbanBoardView(store: store, page: page)
                case .preview:
                    TypstPreviewView(svgString: store.currentSvg)
                case .source:
                    rawSourceEditorView
                }

                // Slide-over Drawer for Typst Live Preview
                if store.isPreviewDrawerPresented && store.currentViewMode != .preview {
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
        }
        .onAppear {
            self.titleBuffer = page.title
        }
        .onChange(of: page.id) { _, _ in
            self.titleBuffer = page.title
        }
    }

    // MARK: - Top Navigation Bar

    private var topNavigationBar: some View {
        HStack(spacing: 14) {
            // Breadcrumb / Title
            HStack(spacing: 6) {
                Image(systemName: page.icon)
                    .foregroundStyle(.tint)
                    .font(.caption)

                Text(page.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
            }
            .frame(maxWidth: 220, alignment: .leading)

            Spacer()

            // View Switcher Tabs (Document / Board / Typst / Source)
            Picker("View", selection: $store.currentViewMode) {
                ForEach(CanvasViewMode.allCases) { mode in
                    Label(mode.rawValue, systemImage: mode.icon)
                        .tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 380)

            Spacer()

            // Actions: Star, Preview Toggle, Info
            HStack(spacing: 8) {
                Button(action: {
                    store.toggleFavorite(id: page.id)
                }) {
                    Image(systemName: page.isFavorite ? "star.fill" : "star")
                        .font(.subheadline)
                        .foregroundStyle(page.isFavorite ? .yellow : .secondary)
                }
                .buttonStyle(.plain)
                .help("Toggle Favorite")

                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        store.isPreviewDrawerPresented.toggle()
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                        Text("Preview")
                            .font(.caption.weight(.medium))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(store.isPreviewDrawerPresented ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.08))
                    .foregroundStyle(store.isPreviewDrawerPresented ? Color.accentColor : Color.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .help("Toggle Live Typst Vector Drawer (Cmd+P)")
                .keyboardShortcut("p", modifiers: .command)
            }
        }
    }

    // MARK: - Document Canvas Body (WYSIWYG Centered Layout)

    private var documentCanvasBody: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 20) {
                // Page Icon & Header
                pageHeaderView

                Divider()

                // Interactive In-Place Block Editor
                BlockListView(store: store, page: page)

                Spacer(minLength: 80)
            }
            .frame(maxWidth: 720)
            .padding(.horizontal, 32)
            .padding(.top, 36)
            .frame(maxWidth: .infinity)
        }
    }

    private var pageHeaderView: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Large Document Icon
            Button(action: { isIconPickerOpen.toggle() }) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.accentColor.opacity(0.12))
                        .frame(width: 52, height: 52)

                    Image(systemName: page.icon)
                        .font(.system(size: 26))
                        .foregroundStyle(.tint)
                }
            }
            .buttonStyle(.plain)
            .popover(isPresented: $isIconPickerOpen) {
                iconPickerSheet
            }

            // Editable Large Title
            TextField("Page Title", text: $titleBuffer)
                .textFieldStyle(.plain)
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(.primary)
                .onChange(of: titleBuffer) { _, newVal in
                    store.updatePageTitle(newVal)
                }

            // Meta Info: Timestamp, ACP WebSocket Status
            HStack(spacing: 12) {
                Label("Edited just now", systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                    Text("ACP ws://127.0.0.1:8080")
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.1))
                .clipShape(Capsule())

                Spacer()
            }
        }
    }

    private var iconPickerSheet: some View {
        let icons = [
            "doc.text.fill", "bolt.fill", "cpu.fill", "sparkles", "books.vertical.fill",
            "folder.fill", "note.text", "checklist", "star.fill", "lightbulb.fill",
            "hammer.fill", "flag.fill", "gearshape.fill", "terminal.fill"
        ]

        return LazyVGrid(columns: Array(repeating: GridItem(.fixed(36)), count: 5), spacing: 8) {
            ForEach(icons, id: \.self) { icon in
                Button(action: {
                    if let idx = store.pages.firstIndex(where: { $0.id == page.id }) {
                        store.pages[idx].icon = icon
                    }
                    isIconPickerOpen = false
                }) {
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .frame(width: 32, height: 32)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
    }

    // MARK: - Raw Source Editor View

    private var rawSourceEditorView: some View {
        HSplitView {
            VStack(alignment: .leading, spacing: 6) {
                Text("Pustaka Fast Syntax / Markdown Source")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.top, 10)

                TextEditor(text: Binding(
                    get: { page.rawContent },
                    set: { store.updatePageContent($0) }
                ))
                .font(.system(.body, design: .monospaced))
                .padding(8)
                .scrollContentBackground(.hidden)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .padding(12)
            }
            .frame(minWidth: 320)

            VStack(alignment: .leading, spacing: 6) {
                Text("Generated RON-RS Block Tree")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.top, 10)

                ScrollView {
                    Text(store.currentRon)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .padding(12)
            }
            .frame(minWidth: 320)
        }
    }
}
