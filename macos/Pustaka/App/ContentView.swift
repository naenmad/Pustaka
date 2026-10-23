import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var store = WorkspaceStore()
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var isAIAssistantPresented: Bool = false
    @State private var isFullScreen: Bool = false
    @State private var isQuickSearchPresented: Bool = false
    @AppStorage("appAppearance") private var appAppearance: String = "system"
    @AppStorage("appPrimaryColorHex") private var appPrimaryColorHex: String = "#007AFF"
    @AppStorage("appUiScale") private var appUiScale: Double = 1.0

    private var primaryColor: Color {
        Color(hex: appPrimaryColorHex)
    }

    private var preferredScheme: ColorScheme? {
        switch appAppearance {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(
                store: store,
                columnVisibility: $columnVisibility,
                isQuickSearchPresented: $isQuickSearchPresented
            )
                .navigationSplitViewColumnWidth(
                    min: 200 * CGFloat(appUiScale),
                    ideal: 240 * CGFloat(appUiScale),
                    max: 340 * CGFloat(appUiScale)
                )
                .background(Color(nsColor: .windowBackgroundColor))
        } detail: {
            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    // Browser-Style Top Header Bar (Sidebar Toggle on LEFT, Browser Tabs in CENTER, Share & 3-Dots on RIGHT)
                    browserTopBar

                    Divider().opacity(0.35)

                    if store.isShowingTrash {
                        TrashPageView(store: store)
                    } else if let page = store.selectedPage {
                        DocumentCanvasView(store: store, page: page)
                            .id(page.id)
                    } else {
                        noDocumentEmptyState
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if isAIAssistantPresented {
                    Divider().opacity(0.35)
                    AIAssistantPanelView(store: store, isPresented: $isAIAssistantPresented)
                        .transition(.move(edge: .trailing))
                }
            }
            .background(Color(nsColor: .windowBackgroundColor))
            .ignoresSafeArea(.container, edges: .top)
        }
        .toolbar(removing: .sidebarToggle)
        .tint(Color(hex: appPrimaryColorHex))
        .preferredColorScheme(preferredScheme)
        .background(WindowConfigurator())
        .background(tabKeyboardShortcuts)
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didEnterFullScreenNotification)) { _ in
            isFullScreen = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didExitFullScreenNotification)) { _ in
            isFullScreen = false
        }
        .sheet(isPresented: $store.isPreviewDrawerPresented) {
            if let page = store.selectedPage {
                TypstPreviewView(
                    svgString: store.generateTypstSvg(for: page),
                    onClose: { store.isPreviewDrawerPresented = false }
                )
                .frame(minWidth: 680, idealWidth: 760, minHeight: 620, idealHeight: 780)
            }
        }
        .overlay {
            if isQuickSearchPresented {
                QuickSearchPaletteView(store: store, isPresented: $isQuickSearchPresented)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
        .animation(.spring(response: 0.22, dampingFraction: 0.85), value: isQuickSearchPresented)
        .background {
            Button(action: {
                withAnimation(.spring(response: 0.22, dampingFraction: 0.85)) {
                    isQuickSearchPresented.toggle()
                }
            }) {
                EmptyView()
            }
            .keyboardShortcut("k", modifiers: [.command])
            .opacity(0)
        }
    }

    // MARK: - Browser-Style Top Header Bar (40pt Height, Aligned with Traffic Lights)

    private var browserTopBar: some View {
        HStack(spacing: 8) {
            // When sidebar is collapsed/hidden, reserve space for macOS Traffic Lights on the far left (only in windowed mode)
            if columnVisibility == .detailOnly && !isFullScreen {
                Spacer()
                    .frame(width: 70 * CGFloat(appUiScale))
            }

            // 1. Toggle Sidebar Button (POJOK KIRI PAGE DOCUMENTNYA, PERSIS SEBELAH KANAN SIDEBAR)
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    NSApp.sendAction(#selector(NSSplitViewController.toggleSidebar(_:)), to: nil, from: nil)
                }
            }) {
                Image(systemName: "sidebar.leading")
                    .font(.system(size: 13 * CGFloat(appUiScale), weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 28 * CGFloat(appUiScale), height: 28 * CGFloat(appUiScale))
                    .background(Color.primary.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .help("Toggle Sidebar (⌃⌘S)")

            Divider()
                .frame(height: 18 * CGFloat(appUiScale))
                .opacity(0.3)

            // 2. Browser-Style Horizontal Document Tab Bar (Supports multiple tabs including Trash)
            DocumentTabBarView(store: store)
                .frame(maxWidth: .infinity, alignment: .leading)

            // 3. Trailing Document Actions (Share & 3-Dots for Document, Finder & Empty for Trash)
            if store.isShowingTrash {
                HStack(spacing: 6) {
                    Button(action: {
                        store.revealTrashInFinder()
                    }) {
                        Image(systemName: "folder")
                            .font(.system(size: 13 * CGFloat(appUiScale), weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(width: 28 * CGFloat(appUiScale), height: 28 * CGFloat(appUiScale))
                            .background(Color.primary.opacity(0.04))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .help("Reveal .trash in Finder")

                    if !store.trashPages.isEmpty {
                        Button(action: {
                            NotificationCenter.default.post(name: NSNotification.Name("PromptEmptyTrash"), object: nil)
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "trash")
                                    .font(.system(size: 11 * CGFloat(appUiScale), weight: .semibold))
                                Text("Empty...")
                                    .font(.system(size: 11 * CGFloat(appUiScale), weight: .medium))
                            }
                            .foregroundStyle(.red.opacity(0.9))
                            .padding(.horizontal, 8 * CGFloat(appUiScale))
                            .padding(.vertical, 4 * CGFloat(appUiScale))
                            .background(Color.red.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                        .help("Empty all items in Trash")
                    }
                }
            } else if let page = store.selectedPage {
                HStack(spacing: 6) {
                    // Share & Export Menu
                    Menu {
                        Button(action: {
                            _ = store.generateTypstSvg(for: page)
                            store.isPreviewDrawerPresented = true
                        }) {
                            Label("Preview Typst Typesetting...", systemImage: "sparkles")
                        }
                        Divider()
                        Button(action: { exportDocument(page: page, format: "md") }) {
                            Label("Export as Markdown (.md)", systemImage: "arrow.down.doc")
                        }
                        Button(action: { exportDocument(page: page, format: "typ") }) {
                            Label("Export as Typst (.typ)", systemImage: "arrow.down.doc")
                        }
                        Divider()
                        Button(action: {
                            NSPasteboard.general.clearContents()
                            let md = "# \(page.title)\n\n\(page.rawContent)"
                            NSPasteboard.general.setString(md, forType: .string)
                        }) {
                            Label("Copy Full Markdown", systemImage: "doc.on.doc")
                        }
                        Button(action: {
                            let svg = store.generateTypstSvg(for: page)
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(svg, forType: .string)
                        }) {
                            Label("Copy Typst SVG Vector", systemImage: "sparkle.magnifyingglass")
                        }
                        Divider()
                        Button(action: { store.revealInFinder(pageId: page.id) }) {
                            Label("Reveal in Finder", systemImage: "folder")
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 13 * CGFloat(appUiScale), weight: .regular))
                            .foregroundStyle(.secondary)
                            .frame(width: 28 * CGFloat(appUiScale), height: 28 * CGFloat(appUiScale))
                            .background(Color.primary.opacity(0.04))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .help("Export & Share Document")

                    // Page Options Menu (Three Dots ...)
                    Menu {
                        Button(action: { store.addNewSubpage(parentPageId: page.id) }) {
                            Label("Add Subpage", systemImage: "doc.badge.plus")
                        }
                        Divider()
                        Button(action: {
                            NotificationCenter.default.post(name: NSNotification.Name("OpenCoverPicker"), object: nil)
                        }) {
                            Label(page.coverUrl.isEmpty ? "Add Cover" : "Change Cover", systemImage: "photo")
                        }
                        Button(action: {
                            NotificationCenter.default.post(name: NSNotification.Name("OpenIconPicker"), object: nil)
                        }) {
                            Label(page.icon.isEmpty ? "Add Icon" : "Change Icon", systemImage: "sparkles")
                        }
                        Divider()
                        Button(action: { store.revealInFinder(pageId: page.id) }) {
                            Label("Reveal in Finder", systemImage: "folder")
                        }
                        Divider()
                        Button(action: { store.duplicatePage(id: page.id) }) {
                            Label("Duplicate Page", systemImage: "plus.square.on.square")
                        }
                        Button(action: { store.toggleFavorite(id: page.id) }) {
                            Label(
                                page.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                                systemImage: page.isFavorite ? "star.fill" : "star"
                            )
                        }
                        Button(action: {
                            NSPasteboard.general.clearContents()
                            let md = page.title.isEmpty ? "Untitled" : page.title
                            NSPasteboard.general.setString(md, forType: .string)
                        }) {
                            Label("Copy Page Title", systemImage: "text.quote")
                        }
                        Divider()
                        Button(role: .destructive, action: { store.deletePage(id: page.id) }) {
                            Label("Move to Trash", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 13 * CGFloat(appUiScale), weight: .regular))
                            .foregroundStyle(.secondary)
                            .frame(width: 28 * CGFloat(appUiScale), height: 28 * CGFloat(appUiScale))
                            .background(Color.primary.opacity(0.04))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .help("Page Options")

                    // AI Assistant Toggle
                    aiAssistantButton
                }
            } else {
                HStack(spacing: 6) {
                    aiAssistantButton
                }
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 40 * CGFloat(appUiScale))
        .background(Color(nsColor: .windowBackgroundColor))
        .background(WindowDragView())
    }

    // MARK: - AI Assistant Button

    private var aiAssistantButton: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.18)) {
                isAIAssistantPresented.toggle()
            }
        }) {
            Image(systemName: "sparkles")
                .font(.system(size: 13 * CGFloat(appUiScale), weight: .regular))
                .foregroundStyle(isAIAssistantPresented ? primaryColor : Color.secondary)
                .frame(width: 28 * CGFloat(appUiScale), height: 28 * CGFloat(appUiScale))
                .background(isAIAssistantPresented ? primaryColor.opacity(0.12) : Color.primary.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .help(isAIAssistantPresented ? "Hide AI Assistant (⌘J)" : "Open AI Assistant (⌘J)")
    }

    // MARK: - Window Configurator (Disables Default Toolbar, Enables FullSize Content)

    struct WindowConfigurator: NSViewRepresentable {
        func makeNSView(context: Context) -> NSView {
            let view = NSView()
            DispatchQueue.main.async {
                if let window = view.window {
                    configure(window: window)
                }
            }
            return view
        }

        func updateNSView(_ nsView: NSView, context: Context) {
            if let window = nsView.window {
                configure(window: window)
            }
        }

        private func configure(window: NSWindow) {
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.toolbar = nil
            window.titlebarSeparatorStyle = .none
            window.tabbingMode = .disallowed
            
            // Explicitly enable full screen and window tiling behavior
            window.collectionBehavior = [.fullScreenPrimary, .fullScreenAllowsTiling]
            
            // Ensure macOS traffic light buttons (Close, Minimize, FullScreen/Zoom) are visible & active
            window.standardWindowButton(.closeButton)?.isHidden = false
            window.standardWindowButton(.miniaturizeButton)?.isHidden = false
            window.standardWindowButton(.zoomButton)?.isHidden = false
            window.standardWindowButton(.zoomButton)?.isEnabled = true
        }
    }

    // MARK: - Export Action Helper

    private func exportDocument(page: DocumentPage, format: String) {
        let panel = NSSavePanel()
        panel.title = "Export Document"
        let safeTitle = page.title.trimmingCharacters(in: .whitespaces).isEmpty ? "Untitled" : page.title
        panel.nameFieldStringValue = "\(safeTitle).\(format)"
        panel.allowedContentTypes = [UTType(filenameExtension: format) ?? .plainText]
        panel.canCreateDirectories = true

        let content: String
        if format == "typ" {
            content = "= \(page.title)\n\n\(page.rawContent)"
        } else {
            content = "# \(page.title)\n\n\(page.rawContent)"
        }

        if panel.runModal() == .OK, let url = panel.url {
            try? content.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    // MARK: - Tab Keyboard Shortcuts (⌘T, ⌘W, ⌘⇧], ⌘⇧[)

    private var tabKeyboardShortcuts: some View {
        Group {
            // ⌘T -> New Document Tab
            Button("") {
                withAnimation(.easeInOut(duration: 0.15)) {
                    store.addNewPage()
                }
            }
            .keyboardShortcut("t", modifiers: .command)

            // ⌘W -> Close Active Tab
            Button("") {
                if let sel = store.selectedPageId {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        store.closeTab(pageId: sel)
                    }
                }
            }
            .keyboardShortcut("w", modifiers: .command)

            // ⌘⇧] -> Select Next Tab
            Button("") {
                withAnimation(.easeInOut(duration: 0.15)) {
                    store.selectNextTab()
                }
            }
            .keyboardShortcut("]", modifiers: [.command, .shift])

            // ⌘⇧[ -> Select Previous Tab
            Button("") {
                withAnimation(.easeInOut(duration: 0.15)) {
                    store.selectPreviousTab()
                }
            }
            .keyboardShortcut("[", modifiers: [.command, .shift])

            // ⌘J -> Toggle AI Assistant
            Button("") {
                withAnimation(.easeInOut(duration: 0.18)) {
                    isAIAssistantPresented.toggle()
                }
            }
            .keyboardShortcut("j", modifiers: .command)
        }
        .opacity(0)
        .frame(width: 0, height: 0)
    }

    // MARK: - Empty State (When All Tabs Are Closed)

    private var noDocumentEmptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .resizable()
                .scaledToFit()
                .frame(width: 44, height: 44)
                .foregroundStyle(.secondary.opacity(0.5))

            Text("No Open Document")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)

            Text("Choose a document from the sidebar or open a new tab.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button(action: {
                withAnimation(.easeInOut(duration: 0.15)) {
                    store.addNewPage()
                }
            }) {
                Label("New Document (⌘T)", systemImage: "plus")
                    .font(.subheadline.weight(.medium))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

#Preview {
    ContentView()
}
