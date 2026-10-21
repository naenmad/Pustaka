import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var store = WorkspaceStore()
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @AppStorage("appAppearance") private var appAppearance: String = "system"

    private var preferredScheme: ColorScheme? {
        switch appAppearance {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(store: store, columnVisibility: $columnVisibility)
                .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 320)
                .background(Color(nsColor: .windowBackgroundColor))
                .toolbar(removing: .sidebarToggle)
        } detail: {
            Group {
                if let page = store.selectedPage {
                    DocumentCanvasView(store: store, page: page)
                        .id(page.id)
                } else {
                    noDocumentEmptyState
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .windowBackgroundColor))
            .toolbar {
                // Center / Leading Detail Toolbar Item: Sidebar Toggle + Document Tabs
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                NSApp.sendAction(#selector(NSSplitViewController.toggleSidebar(_:)), to: nil, from: nil)
                            }
                        }) {
                            Image(systemName: "sidebar.leading")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                                .frame(width: 24, height: 24)
                                .background(Color.primary.opacity(0.04))
                                .clipShape(RoundedRectangle(cornerRadius: 5))
                        }
                        .buttonStyle(.plain)
                        .help("Toggle Sidebar (⌃⌘S)")

                        Divider()
                            .frame(height: 16)
                            .opacity(0.3)

                        DocumentTabBarView(store: store)
                    }
                }

                // Far Right Corner (Segaris di Pojok Kanan Appbar): Share & 3-Dots Buttons
                if let page = store.selectedPage {
                    ToolbarItemGroup(placement: .primaryAction) {
                        // 1. Share & Export Menu
                        Menu {
                            Button(action: { exportDocument(page: page, format: "md") }) {
                                Label("Export as Markdown (.md)", systemImage: "arrow.down.doc")
                            }
                            Button(action: { exportDocument(page: page, format: "typ") }) {
                                Label("Export as Typst (.typ)", systemImage: "arrow.down.doc.fill")
                            }
                            Divider()
                            Button(action: {
                                NSPasteboard.general.clearContents()
                                let md = "# \(page.title)\n\n\(page.rawContent)"
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
                            Button(action: { store.revealInFinder(pageId: page.id) }) {
                                Label("Reveal in Finder", systemImage: "folder")
                            }
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .help("Export & Share Document")

                        // 2. Page Options Menu (Three Dots ...)
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
                                Label(page.icon.isEmpty ? "Add Icon" : "Change Icon", systemImage: "face.smiling")
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
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .help("Page Options")
                    }
                }
            }
        }
        .toolbar(removing: .sidebarToggle)
        .navigationTitle("")
        .preferredColorScheme(preferredScheme)
        .background(tabKeyboardShortcuts)
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
